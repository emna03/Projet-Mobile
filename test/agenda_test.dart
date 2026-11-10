import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studymate/features/calendar/agenda_entries.dart';
import 'package:studymate/features/calendar/agenda_page.dart';
import 'package:studymate/features/calendar/calendar_event.dart';
import 'package:studymate/features/calendar/google_calendar_api.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/features/seances/seance_user.dart';
import 'package:studymate/features/seances/seances_database.dart';
import 'package:studymate/features/seances/seances_store.dart';

const _dbName = 'studymate_agenda_test.db';
const _alex = SeanceUser(
  id: 'user-ab',
  displayName: 'Alex Benali',
  initials: 'AB',
);

Seance _seance({
  String id = 'docker',
  String title = 'Docker, de zéro à déployé',
  DateTime? date,
  bool reserved = true,
  String? calendarEventId,
}) {
  return Seance(
    id: id,
    ownerId: 'user-yassine',
    subject: 'Docker',
    title: title,
    host: 'Yassine Trabelsi',
    date: date ?? DateTime(2026, 10, 7),
    start: const TimeOfDay(hour: 18, minute: 0),
    end: const TimeOfDay(hour: 19, minute: 30),
    format: SessionFormat.online,
    place: 'https://meet.google.com/abc-defg-hij',
    seatsLeft: 4,
    reserved: reserved,
    calendarEventId: calendarEventId,
  );
}

CalendarEvent _event(
  String id,
  String title, {
  DateTime? start,
  String? seanceId,
}) {
  final begin = start ?? DateTime(2026, 10, 7, 10);
  return CalendarEvent(
    id: id,
    title: title,
    start: begin,
    end: begin.add(const Duration(hours: 1)),
    seanceId: seanceId,
  );
}

Map<String, Object?> _eventJson(String id, String title, String startIso) {
  final start = DateTime.parse(startIso);
  return {
    'id': id,
    'summary': title,
    'start': {'dateTime': startIso},
    'end': {'dateTime': start.add(const Duration(hours: 1)).toIso8601String()},
  };
}

http.Response _json(Map<String, Object?> body, [int status = 200]) {
  return http.Response(jsonEncode(body), status);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    await deleteDatabase(path);
  });

  group('CalendarEvent.fromJson', () {
    test('reads a timed event and the StudyMate marker', () {
      final event = CalendarEvent.fromJson({
        'id': 'e1',
        'summary': ' Cours de maths ',
        'location': 'Salle B12',
        'htmlLink': 'https://calendar.google.com/event?eid=e1',
        'start': {'dateTime': '2026-10-07T10:00:00Z'},
        'end': {'dateTime': '2026-10-07T11:00:00Z'},
        'extendedProperties': {
          'private': {'studymateSeanceId': 'docker'},
        },
      })!;

      expect(event.title, 'Cours de maths');
      expect(event.location, 'Salle B12');
      expect(event.allDay, isFalse);
      expect(event.start.toUtc(), DateTime.utc(2026, 10, 7, 10));
      expect(event.end.toUtc(), DateTime.utc(2026, 10, 7, 11));
      expect(event.seanceId, 'docker');
      expect(event.fromStudyMate, isTrue);
    });

    test('reads an all-day event with a date and no title', () {
      final event = CalendarEvent.fromJson({
        'id': 'e2',
        'start': {'date': '2026-10-08'},
        'end': {'date': '2026-10-09'},
      })!;

      expect(event.allDay, isTrue);
      expect(event.title, '(Sans titre)');
      expect(event.start, DateTime(2026, 10, 8));
      expect(event.end, DateTime(2026, 10, 9));
      expect(event.fromStudyMate, isFalse);
    });

    test('ignores cancelled and unreadable events', () {
      expect(
        CalendarEvent.fromJson({
          'id': 'e3',
          'status': 'cancelled',
          'start': {'date': '2026-10-08'},
        }),
        isNull,
      );
      expect(CalendarEvent.fromJson({'id': 'e4'}), isNull);
      expect(
        CalendarEvent.fromJson({
          'id': 'e5',
          'start': {'dateTime': 'pas une date'},
        }),
        isNull,
      );
    });
  });

  group('listEvents', () {
    test('asks for the month and follows the pages', () async {
      final requests = <http.Request>[];
      final api = GoogleCalendarApi(
        accessToken: () async => 'token-1',
        onUnauthorized: (_) async {},
        client: _ScriptedClient((request) async {
          requests.add(request);
          if (request.url.queryParameters['pageToken'] == null) {
            return _json({
              'items': [_eventJson('a', 'Premier', '2026-10-07T10:00:00Z')],
              'nextPageToken': 'page-2',
            });
          }
          return _json({
            'items': [
              _eventJson('b', 'Second', '2026-10-08T10:00:00Z'),
              {'id': 'x', 'status': 'cancelled'},
            ],
          });
        }),
      );

      final events = await api.listEvents(
        from: DateTime(2026, 10),
        to: DateTime(2026, 11),
      );

      expect(events.map((e) => e.title), ['Premier', 'Second']);
      expect(requests, hasLength(2));
      final query = requests.first.url.queryParameters;
      expect(query['timeMin'], DateTime(2026, 10).toUtc().toIso8601String());
      expect(query['timeMax'], DateTime(2026, 11).toUtc().toIso8601String());
      expect(query['singleEvents'], 'true');
      expect(query['orderBy'], 'startTime');
      expect(requests.first.headers['Authorization'], 'Bearer token-1');
      expect(requests.last.url.queryParameters['pageToken'], 'page-2');
    });
  });

  group('buildAgenda', () {
    final from = DateTime(2026, 10);
    final to = DateTime(2026, 11);

    test('merges events and reserved seances in date order', () {
      final entries = buildAgenda(
        events: [
          _event('late', 'Dentiste', start: DateTime(2026, 10, 20, 9)),
          _event('early', 'Sport', start: DateTime(2026, 10, 7, 8)),
        ],
        reserved: [_seance()],
        from: from,
        to: to,
      );

      expect(entries.map((e) => e.label), [
        'Sport',
        'Docker, de zéro à déployé',
        'Dentiste',
      ]);
      expect(entries.map((e) => e.isSeance), [false, true, false]);
    });

    test('shows a seance once when its event is in the calendar', () {
      final byEventId = buildAgenda(
        events: [_event('evt-1', 'Docker, de zéro à déployé')],
        reserved: [_seance(calendarEventId: 'evt-1')],
        from: from,
        to: to,
      );
      final bySeanceId = buildAgenda(
        events: [_event('evt-9', 'Docker', seanceId: 'docker')],
        reserved: [_seance()],
        from: from,
        to: to,
      );

      expect(byEventId, hasLength(1));
      expect(byEventId.single.isSeance, isTrue);
      expect(bySeanceId, hasLength(1));
      expect(bySeanceId.single.isSeance, isTrue);
    });

    test('keeps StudyMate events of seances that are not reserved', () {
      final entries = buildAgenda(
        events: [_event('evt-2', 'Ma séance', seanceId: 'flutter')],
        reserved: [_seance()],
        from: from,
        to: to,
      );

      expect(entries, hasLength(2));
      expect(entries.firstWhere((e) => !e.isSeance).event!.fromStudyMate, isTrue);
    });

    test('leaves out reserved seances outside the month', () {
      final entries = buildAgenda(
        events: const [],
        reserved: [_seance(date: DateTime(2026, 11, 2))],
        from: from,
        to: to,
      );

      expect(entries, isEmpty);
    });

    test('groups entries by day', () {
      final entries = buildAgenda(
        events: [
          _event('a', 'Matin', start: DateTime(2026, 10, 7, 8)),
          _event('b', 'Autre jour', start: DateTime(2026, 10, 9, 8)),
        ],
        reserved: [_seance()],
        from: from,
        to: to,
      );
      final groups = groupByDay(entries);

      expect(groups.map((g) => g.day), [
        DateTime(2026, 10, 7),
        DateTime(2026, 10, 9),
      ]);
      expect(groups.first.entries, hasLength(2));
    });
  });

  group('AgendaPage', () {
    late List<http.Request> requests;

    Future<SeancesStore> openStore(
      http.Response Function(http.Request request) handler,
    ) async {
      requests = [];
      final api = GoogleCalendarApi(
        accessToken: () async => 'token-1',
        onUnauthorized: (_) async {},
        client: _ScriptedClient((request) async {
          requests.add(request);
          return handler(request);
        }),
      );
      final store = SeancesStore(
        database: SeancesDatabase(fileName: _dbName),
        loadUser: () async => _alex,
        calendar: api,
      );
      await store.load();
      return store;
    }

    Future<void> showPage(WidgetTester tester, SeancesStore store) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: AgendaPage(store: store, initialMonth: DateTime(2026, 10)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists Google events with the reserved seance once', (
      tester,
    ) async {
      final store = (await tester.runAsync(
        () => openStore(
          (_) => _json({
            'items': [
              _eventJson('e1', 'Rendez-vous dentiste', '2026-10-07T10:00:00Z'),
              {
                ..._eventJson('e2', 'Docker (agenda)', '2026-10-07T17:00:00Z'),
                'extendedProperties': {
                  'private': {'studymateSeanceId': 'docker'},
                },
              },
            ],
          }),
        ),
      ))!;

      await showPage(tester, store);

      expect(find.text('Mon agenda'), findsOneWidget);
      expect(find.text('octobre 2026'), findsOneWidget);
      expect(find.text('Rendez-vous dentiste'), findsOneWidget);
      expect(find.text('Docker, de zéro à déployé'), findsOneWidget);
      expect(find.text('Docker (agenda)'), findsNothing);
      expect(find.text('Séance réservée'), findsOneWidget);
    });

    testWidgets('keeps the reserved seance when Google Calendar fails', (
      tester,
    ) async {
      final store = (await tester.runAsync(
        () => openStore(
          (_) => _json({
            'error': {'message': 'Accès refusé.'},
          }, 403),
        ),
      ))!;

      await showPage(tester, store);

      expect(find.textContaining('Google Agenda indisponible'), findsOneWidget);
      expect(find.textContaining('Accès refusé.'), findsOneWidget);
      expect(find.text('Docker, de zéro à déployé'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('loads the next month and hides the other month seance', (
      tester,
    ) async {
      final store = (await tester.runAsync(
        () => openStore((_) => _json({'items': <Object?>[]})),
      ))!;

      await showPage(tester, store);
      expect(find.text('Docker, de zéro à déployé'), findsOneWidget);

      await tester.tap(find.byTooltip('Mois suivant'));
      await tester.pumpAndSettle();

      expect(find.text('novembre 2026'), findsOneWidget);
      expect(find.text('Docker, de zéro à déployé'), findsNothing);
      expect(find.text('Rien de prévu ce mois-ci.'), findsOneWidget);
      expect(
        requests.last.url.queryParameters['timeMin'],
        DateTime(2026, 11).toUtc().toIso8601String(),
      );
    });
  });
}

class _ScriptedClient extends http.BaseClient {
  _ScriptedClient(this._handler);

  final Future<http.Response> Function(http.Request request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request as http.Request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}
