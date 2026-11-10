import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studymate/features/availability/availability_models.dart';
import 'package:studymate/features/calendar/agenda_page.dart';
import 'package:studymate/features/calendar/google_calendar_api.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/features/seances/proposer_seance_page.dart';
import 'package:studymate/features/seances/seance_user.dart';
import 'package:studymate/features/seances/seances_database.dart';
import 'package:studymate/features/seances/seances_page.dart';
import 'package:studymate/features/seances/seances_store.dart';
import 'package:studymate/features/seances/widgets/seance_card.dart';

const _dbName = 'studymate_conflicts_test.db';
const _alex = SeanceUser(
  id: 'user-ab',
  displayName: 'Alex Benali',
  initials: 'AB',
);

/// Mardi 10 novembre 2026, 09:00 : les séances d'exemple sont à venir.
final _november = DateTime(2026, 11, 10, 9);

/// Jeudi 1er octobre 2026 : les séances de départ (octobre) sont à venir.
final _october = DateTime(2026, 10, 1, 9);

class _ScriptedClient extends http.BaseClient {
  _ScriptedClient(this._handler);

  final http.Response Function(http.Request request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = _handler(request as http.Request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

http.Response _noEvents(http.Request request) =>
    http.Response(jsonEncode({'items': <Object?>[]}), 200);

/// Séance que je propose le 8 octobre, à cheval sur « Spring Boot »
/// (14:00 – 15:30), que je n'ai pas réservée.
Seance _mine({int fromHour = 14, int fromMinute = 30}) {
  return Seance(
    id: 'mine',
    ownerId: _alex.id,
    subject: 'Java',
    title: 'Atelier Java',
    host: 'Alex Benali',
    date: DateTime(2026, 10, 8),
    start: TimeOfDay(hour: fromHour, minute: fromMinute),
    end: TimeOfDay(hour: fromHour + 1, minute: fromMinute),
    format: SessionFormat.online,
    place: 'https://meet.google.com/abc-defg-hij',
    seatsLeft: 5,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    await deleteDatabase(path);
  });

  SeancesStore newStore(
    DateTime now, {
    http.Response Function(http.Request request) calendar = _noEvents,
  }) {
    return SeancesStore(
      database: SeancesDatabase(fileName: _dbName),
      loadUser: () async => _alex,
      clock: () => now,
      calendar: GoogleCalendarApi(
        accessToken: () async => 'token',
        onUnauthorized: (_) async {},
        client: _ScriptedClient(calendar),
      ),
    );
  }

  group('store: seance against seance', () {
    test('the example seances contain one deliberate conflict', () async {
      final store = newStore(_november);
      await store.load();
      expect(store.conflictCount, 0);

      await store.loadDemoData(now: _november);
      await store.conflictsSettled();

      expect(store.conflictCount, 2);
      expect(store.conflictsOf('demo-algo').map((s) => s.id), ['demo-conflit']);
      expect(store.conflictsOf('demo-conflit').map((s) => s.id), ['demo-algo']);
      expect(store.conflictsOf('demo-sql'), isEmpty);
    });

    test('moving a seance away clears the conflict', () async {
      final store = newStore(_november);
      await store.load();
      await store.loadDemoData(now: _november);
      final extra = store.items.firstWhere((s) => s.id == 'demo-conflit');

      await store.update(
        extra.copyWith(
          start: const TimeOfDay(hour: 8, minute: 0),
          end: const TimeOfDay(hour: 9, minute: 0),
        ),
      );

      expect(store.conflictCount, 0);
      expect(store.conflictsOf('demo-algo'), isEmpty);
    });

    test('deleting a seance clears the conflict', () async {
      final store = newStore(_november);
      await store.load();
      await store.loadDemoData(now: _november);

      expect(await store.delete('demo-conflit'), isTrue);

      expect(store.conflictCount, 0);
    });

    test('a seance I neither own nor reserved is not in conflict', () async {
      final store = newStore(_october);
      await store.load();
      await store.add(_mine());
      final spring = store.items.firstWhere((s) => s.id == 'spring');

      // Je ne participe pas à Spring Boot : pas de conflit pour l'instant…
      expect(store.conflictCount, 0);
      // … mais la réserver en créerait un.
      expect(store.conflictsFor(spring).map((s) => s.id), ['mine']);
    });

    test('reserving creates the conflict and cancelling removes it', () async {
      final store = newStore(_october);
      await store.load();
      await store.add(_mine());

      await store.toggleReservation('spring');
      expect(store.conflictCount, 2);
      expect(store.conflictsOf('spring').map((s) => s.id), ['mine']);

      await store.toggleReservation('spring');
      expect(store.conflictCount, 0);
    });

    test('seances that are over are never reported', () async {
      // En novembre, les séances d'octobre sont passées.
      final store = newStore(_november);
      await store.load();
      await store.add(_mine());
      await store.toggleReservation('spring');
      final spring = store.items.firstWhere((s) => s.id == 'spring');

      expect(store.conflictCount, 0);
      expect(store.conflictsFor(spring), isEmpty);
    });
  });

  group('store: seance against availabilities', () {
    test('names the participants who are not free', () async {
      final store = newStore(_november);
      await store.load();
      await store.loadDemoData(now: _november);
      await store.conflictsSettled();

      // Jeudi 20:00 – 21:30 : seul Yassine (jeu. 18:00–22:00) est libre.
      expect(store.unavailableFor('demo-algo'), [
        'toi',
        'Sarah Ben Ali',
        'Ines Gharbi',
      ]);
      // Sans participant, rien à signaler.
      expect(store.unavailableFor('demo-conflit'), isEmpty);
    });

    test('updates when an availability changes', () async {
      final store = newStore(_november);
      await store.load();
      await store.loadDemoData(now: _november);

      await store.saveAvailability('demo-sarah', [
        const AvailabilityWindow(
          weekday: DateTime.thursday,
          startMinutes: 20 * 60,
          endMinutes: 22 * 60,
        ),
      ]);
      await store.conflictsSettled();

      expect(store.unavailableFor('demo-algo'), ['toi', 'Ines Gharbi']);
    });

    test('updates when a participant is removed or the seance moves', () async {
      final store = newStore(_november);
      await store.load();
      await store.loadDemoData(now: _november);

      await store.removeParticipant('demo-algo', 'demo-ines');
      await store.conflictsSettled();
      expect(store.unavailableFor('demo-algo'), ['toi', 'Sarah Ben Ali']);

      // Mercredi 18:00 – 19:30 : le créneau commun, tout le monde est libre.
      final algo = store.items.firstWhere((s) => s.id == 'demo-algo');
      await store.update(
        algo.copyWith(
          date: DateTime(2026, 11, 11),
          start: const TimeOfDay(hour: 18, minute: 0),
          end: const TimeOfDay(hour: 19, minute: 30),
        ),
      );
      await store.conflictsSettled();
      expect(store.unavailableFor('demo-algo'), isEmpty);
    });
  });

  group('screens', () {
    /// La base répond en temps réel : on alterne attente réelle et image.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
    }

    void tallScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Future<void> showSeances(WidgetTester tester, SeancesStore store) async {
      tallScreen(tester);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SeancesPage(store: store))),
      );
      await settle(tester);
    }

    Finder cardOf(String title) =>
        find.ancestor(of: find.text(title), matching: find.byType(SeanceCard));

    testWidgets('the séances page reports conflicts on the cards', (
      tester,
    ) async {
      final store = newStore(_november);
      await tester.runAsync(() async {
        await store.load();
        await store.loadDemoData(now: _november);
        await store.conflictsSettled();
      });
      await showSeances(tester, store);

      expect(
        find.textContaining('2 de tes séances sont en conflit d\'horaire'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardOf('Révisions Algorithmique'),
          matching: find.textContaining(
            'Conflit d\'horaire : chevauche « Point projet intégré » '
            '(20:30 – 21:30)',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardOf('Révisions Algorithmique'),
          matching: find.text(
            'Indisponible à cette heure : toi, Sarah Ben Ali, Ines Gharbi',
          ),
        ),
        findsOneWidget,
      );
      // Une séance sans conflit n'a pas de bandeau.
      expect(
        find.descendant(
          of: cardOf('Point projet intégré'),
          matching: find.textContaining('Indisponible'),
        ),
        findsNothing,
      );
    });

    testWidgets('no conflict means no summary', (tester) async {
      final store = newStore(_october);
      await tester.runAsync(store.load);
      await showSeances(tester, store);

      expect(find.textContaining('en conflit d\'horaire'), findsNothing);
      expect(find.textContaining('Conflit d\'horaire'), findsNothing);
    });

    testWidgets('reserving an overlapping seance asks first', (tester) async {
      final store = newStore(_october);
      await tester.runAsync(() async {
        await store.load();
        await store.add(_mine());
      });
      await showSeances(tester, store);
      final reserve = find.descendant(
        of: cardOf('Construire une API Spring Boot'),
        matching: find.text('Réserver'),
      );

      await tester.tap(reserve);
      await tester.pumpAndSettle();
      expect(find.text('Conflit d\'horaire'), findsOneWidget);
      expect(
        find.textContaining('chevauche « Atelier Java » (14:30 – 15:30)'),
        findsOneWidget,
      );

      await tester.tap(find.text('Annuler'));
      await settle(tester);
      expect(store.items.firstWhere((s) => s.id == 'spring').reserved, isFalse);

      await tester.tap(reserve);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réserver quand même'));
      await settle(tester);

      expect(store.items.firstWhere((s) => s.id == 'spring').reserved, isTrue);
      expect(
        find.textContaining('2 de tes séances sont en conflit d\'horaire'),
        findsOneWidget,
      );
    });

    testWidgets('reserving a free slot does not ask', (tester) async {
      final store = newStore(_october);
      await tester.runAsync(store.load);
      await showSeances(tester, store);

      await tester.tap(
        find.descendant(
          of: cardOf('Construire une API Spring Boot'),
          matching: find.text('Réserver'),
        ),
      );
      await settle(tester);

      expect(find.text('Conflit d\'horaire'), findsNothing);
      expect(store.items.firstWhere((s) => s.id == 'spring').reserved, isTrue);
    });

    testWidgets('the form warns and asks before saving', (tester) async {
      tallScreen(tester);
      final other = _mine();
      Seance? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<Seance>(
                      MaterialPageRoute(
                        builder: (_) => ProposerSeancePage(
                          currentUser: _alex,
                          seance: Seance(
                            id: 'edited',
                            ownerId: _alex.id,
                            subject: 'SQL',
                            title: 'Atelier SQL',
                            host: 'Alex Benali',
                            date: DateTime(2026, 10, 8),
                            start: const TimeOfDay(hour: 15, minute: 0),
                            end: const TimeOfDay(hour: 16, minute: 0),
                            format: SessionFormat.online,
                            place: 'https://meet.google.com/abc-defg-hij',
                            seatsLeft: 6,
                          ),
                          conflictsFor: (_) => [other],
                        ),
                      ),
                    );
                  },
                  child: const Text('Ouvrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Conflit d\'horaire : tu as déjà « Atelier Java » (14:30 – 15:30)',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enregistrer quand même ?'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Enregistrer'), findsOneWidget);

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(result?.id, 'edited');
    });

    testWidgets('the form stays quiet without a conflict', (tester) async {
      tallScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ProposerSeancePage(
            currentUser: _alex,
            conflictsFor: (_) => const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Conflit d\'horaire'), findsNothing);
    });

    testWidgets('the agenda marks a seance that overlaps an event', (
      tester,
    ) async {
      final start = DateTime(2026, 10, 7, 18, 30).toUtc().toIso8601String();
      final end = DateTime(2026, 10, 7, 19, 0).toUtc().toIso8601String();
      final store = newStore(
        _october,
        calendar: (_) => http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'dentist',
                'summary': 'Dentiste',
                'start': {'dateTime': start},
                'end': {'dateTime': end},
              },
              {
                'id': 'free',
                'summary': 'Sport',
                'start': {'dateTime': '2026-10-20T08:00:00Z'},
                'end': {'dateTime': '2026-10-20T09:00:00Z'},
              },
            ],
          }),
          200,
        ),
      );
      await tester.runAsync(store.load);
      tallScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: AgendaPage(store: store, initialMonth: DateTime(2026, 10)),
        ),
      );
      await settle(tester);

      // Docker (réservée, 18:00 – 19:30) chevauche le dentiste : signalé des
      // deux côtés, et pas sur l'événement sans rapport.
      expect(find.text('Conflit'), findsNWidgets(2));
      expect(find.text('Chevauche : Dentiste'), findsOneWidget);
      expect(find.text('Chevauche : Docker, de zéro à déployé'), findsOneWidget);
    });
  });
}
