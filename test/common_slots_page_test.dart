import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studymate/features/availability/common_slots_page.dart';
import 'package:studymate/features/calendar/google_calendar_api.dart';
import 'package:studymate/features/seances/seance_user.dart';
import 'package:studymate/features/seances/seances_database.dart';
import 'package:studymate/features/seances/seances_page.dart';
import 'package:studymate/features/seances/seances_store.dart';

const _dbName = 'studymate_slots_page_test.db';
const _alex = SeanceUser(
  id: 'user-ab',
  displayName: 'Alex Benali',
  initials: 'AB',
);

/// Mardi 10 novembre 2026, 09:00.
final _now = DateTime(2026, 11, 10, 9);

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    await deleteDatabase(path);
  });

  /// La base de données répond en temps réel, pas en temps simulé : on
  /// alterne attente réelle et image tant que les lectures s'enchaînent
  /// (chaque participant demande ses disponibilités l'un après l'autre).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  Future<SeancesStore> openStore(
    WidgetTester tester, {
    http.Response Function(http.Request request) calendar = _noEvents,
    bool demo = true,
  }) async {
    final store = SeancesStore(
      database: SeancesDatabase(fileName: _dbName),
      loadUser: () async => _alex,
      calendar: GoogleCalendarApi(
        accessToken: () async => 'token',
        onUnauthorized: (_) async {},
        client: _ScriptedClient(calendar),
      ),
    );
    await tester.runAsync(() async {
      await store.load();
      if (demo) await store.loadDemoData(now: _now);
    });
    return store;
  }

  Future<void> showPage(
    WidgetTester tester,
    SeancesStore store,
    String seanceId,
  ) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final seance = store.items.firstWhere((s) => s.id == seanceId);
    await tester.pumpWidget(
      MaterialApp(
        home: CommonSlotsPage(store: store, seance: seance, clock: () => _now),
      ),
    );
    await settle(tester);
  }

  testWidgets('lists the participants and the slots everyone can attend', (
    tester,
  ) async {
    final store = await openStore(tester);
    await showPage(tester, store, 'demo-algo');

    expect(find.text('Créneaux communs'), findsOneWidget);
    expect(find.textContaining('Révisions Algorithmique'), findsOneWidget);
    expect(find.text('Participants (4)'), findsOneWidget);
    expect(find.text('Alex Benali (toi)'), findsOneWidget);
    expect(find.text('Sarah Ben Ali'), findsOneWidget);
    expect(find.textContaining('Lun., Mer., Ven. 16:00–20:00'), findsOneWidget);

    expect(find.text('Tout le monde est disponible'), findsOneWidget);
    // Deux créneaux où les 4 sont libres : les mercredis 11 et 18.
    expect(find.text('Les 4 participants sont disponibles'), findsNWidgets(2));
    final cards = find.ancestor(
      of: find.text('Les 4 participants sont disponibles'),
      matching: find.byType(Column),
    );
    expect(
      find.descendant(of: cards.first, matching: find.text('Mer. 11 nov.')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cards.first, matching: find.text('18:00 – 19:30')),
      findsOneWidget,
    );
  });

  testWidgets('shows flexible start times', (tester) async {
    final store = await openStore(tester);
    await showPage(tester, store, 'demo-reseaux');

    expect(
      find.textContaining('18:00 – 19:00 · début possible jusqu\'à 18:30'),
      findsWidgets,
    );
    expect(find.text('Sam. 14 nov.'), findsWidgets);
  });

  testWidgets('offers compromises when nobody is common', (tester) async {
    final store = await openStore(tester);
    await showPage(tester, store, 'demo-flutter');

    expect(find.text('Meilleurs compromis'), findsOneWidget);
    expect(
      find.textContaining('Aucun créneau ne convient à tout le monde'),
      findsOneWidget,
    );
    expect(find.text('Tout le monde est disponible'), findsNothing);
    expect(find.textContaining('4 sur 5 disponibles · manque :'), findsWidgets);
  });

  testWidgets('choosing a slot moves the seance', (tester) async {
    final store = await openStore(tester);
    await showPage(tester, store, 'demo-algo');

    await tester.tap(find.text('Choisir').first);
    await tester.pumpAndSettle();
    expect(find.text('Choisir ce créneau ?'), findsOneWidget);
    expect(
      find.textContaining('Mer. 11 nov. de 18:00 à 19:30'),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Choisir'),
      ),
    );
    await settle(tester);

    final moved = store.items.firstWhere((s) => s.id == 'demo-algo');
    expect(moved.date, DateTime(2026, 11, 11));
    expect(moved.start, const TimeOfDay(hour: 18, minute: 0));
    expect(moved.end, const TimeOfDay(hour: 19, minute: 30));
    expect(find.textContaining('Séance déplacée au'), findsOneWidget);
    // Le créneau qui vient d'être choisi est marqué comme actuel.
    expect(find.text('Actuel'), findsOneWidget);
  });

  testWidgets('cancelling the choice keeps the seance as it was', (
    tester,
  ) async {
    final store = await openStore(tester);
    await showPage(tester, store, 'demo-algo');
    final before = store.items.firstWhere((s) => s.id == 'demo-algo');

    await tester.tap(find.text('Choisir').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await settle(tester);

    final after = store.items.firstWhere((s) => s.id == 'demo-algo');
    expect(after.date, before.date);
    expect(after.start, before.start);
  });

  testWidgets('warns when a compromise leaves someone out', (tester) async {
    final store = await openStore(tester);
    await showPage(tester, store, 'demo-flutter');

    await tester.tap(find.text('Choisir').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Attention :'), findsOneWidget);
    expect(find.textContaining('pas disponible'), findsOneWidget);
  });

  testWidgets('editing a participant availability updates the slots', (
    tester,
  ) async {
    final store = await openStore(tester);
    await showPage(tester, store, 'demo-algo');

    await tester.tap(find.text('Sarah Ben Ali'));
    await tester.pumpAndSettle();
    expect(find.text('Disponibilités de Sarah Ben Ali'), findsOneWidget);

    // Retire la plage du mercredi : plus aucun créneau commun.
    final wednesday = find.textContaining('Mer.  16:00 – 20:00');
    expect(wednesday, findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.ancestor(of: wednesday, matching: find.byType(ListTile)),
        matching: find.byTooltip('Retirer cette plage'),
      ),
    );
    await settle(tester);

    expect(find.textContaining('Mer.  16:00 – 20:00'), findsNothing);
    expect(find.text('Tout le monde est disponible'), findsNothing);
    expect(find.text('Meilleurs compromis'), findsOneWidget);

    final saved = await tester.runAsync(
      () => store.participantsFor('demo-algo'),
    );
    final sarah = saved!.firstWhere((p) => p.id == 'demo-sarah');
    expect(sarah.windows.any((w) => w.weekday == DateTime.wednesday), isFalse);
  });

  testWidgets('adds a participant and opens their availability', (
    tester,
  ) async {
    final store = await openStore(tester);
    await showPage(tester, store, 'demo-algo');

    await tester.tap(find.widgetWithText(TextButton, 'Ajouter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nour Hamdi');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Ajouter'),
      ),
    );
    await settle(tester);

    expect(find.text('Participants (5)'), findsOneWidget);
    expect(find.text('Disponibilités de Nour Hamdi'), findsOneWidget);
  });

  testWidgets('removes a participant', (tester) async {
    final store = await openStore(tester);
    await showPage(tester, store, 'demo-algo');

    await tester.tap(find.byTooltip('Retirer Ines Gharbi'));
    await settle(tester);

    expect(find.text('Participants (3)'), findsOneWidget);
    expect(find.text('Ines Gharbi'), findsNothing);
  });

  testWidgets('my Google Calendar can block a slot', (tester) async {
    final busyStart = DateTime(2026, 11, 11, 18, 30).toUtc().toIso8601String();
    final busyEnd = DateTime(2026, 11, 11, 19, 0).toUtc().toIso8601String();
    final store = await openStore(
      tester,
      calendar: (_) => http.Response(
        jsonEncode({
          'items': [
            {
              'id': 'busy-1',
              'summary': 'Rendez-vous',
              'start': {'dateTime': busyStart},
              'end': {'dateTime': busyEnd},
            },
          ],
        }),
        200,
      ),
    );
    await showPage(tester, store, 'demo-algo');
    final full = find.text('Les 4 participants sont disponibles');
    expect(full, findsNWidgets(2));

    await tester.tap(find.byType(Switch));
    await settle(tester);

    // Le 11 à 18:00 je suis pris : il ne reste que le 18 pour tout le monde.
    expect(full, findsOneWidget);
    final card = find.ancestor(of: full, matching: find.byType(Column)).first;
    expect(
      find.descendant(of: card, matching: find.text('Mer. 18 nov.')),
      findsOneWidget,
    );
    expect(find.textContaining('manque : Alex Benali'), findsWidgets);

    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(find.text('Les 4 participants sont disponibles'), findsNWidgets(2));
  });

  testWidgets('a Google Calendar error leaves the switch off', (tester) async {
    final store = await openStore(
      tester,
      calendar: (_) => http.Response(
        jsonEncode({
          'error': {'message': 'Accès refusé.'},
        }),
        403,
      ),
    );
    await showPage(tester, store, 'demo-algo');

    await tester.tap(find.byType(Switch));
    await settle(tester);

    expect(
      find.textContaining('Google Agenda indisponible : Accès refusé.'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('Les 4 participants sont disponibles'), findsNWidgets(2));
  });

  testWidgets('asks for availabilities when nobody gave any', (tester) async {
    final store = await openStore(tester, demo: false);
    await showPage(tester, store, 'flutter');

    expect(find.text('Participants (1)'), findsOneWidget);
    expect(
      find.textContaining('Personne n\'a encore indiqué de disponibilités'),
      findsOneWidget,
    );
  });

  group('séances page', () {
    Future<void> showSeances(WidgetTester tester, SeancesStore store) async {
      tester.view.physicalSize = const Size(1080, 4200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SeancesPage(store: store)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('loads and clears the example seances', (tester) async {
      final store = await openStore(tester, demo: false);
      await showSeances(tester, store);
      final before = store.items.length;

      await tester.tap(find.text('Charger des séances d\'exemple (test)'));
      await settle(tester);

      expect(store.items.length, before + 4);
      expect(find.text('Supprimer les séances d\'exemple'), findsOneWidget);
      expect(find.text('Révisions Algorithmique'), findsOneWidget);

      await tester.tap(find.text('Supprimer les séances d\'exemple'));
      await settle(tester);

      expect(store.items.length, before);
      expect(
        find.text('Charger des séances d\'exemple (test)'),
        findsOneWidget,
      );
      expect(find.text('Révisions Algorithmique'), findsNothing);
    });

    testWidgets('the menu of an owned seance opens the common slots', (
      tester,
    ) async {
      final store = await openStore(tester, demo: false);
      await showSeances(tester, store);

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Trouver un créneau commun'), findsOneWidget);

      await tester.tap(find.text('Trouver un créneau commun'));
      await settle(tester);

      expect(find.text('Créneaux communs'), findsOneWidget);
    });
  });
}
