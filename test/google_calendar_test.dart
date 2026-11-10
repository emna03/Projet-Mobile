import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studymate/features/calendar/google_calendar_api.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/features/seances/seance_user.dart';
import 'package:studymate/features/seances/seances_database.dart';
import 'package:studymate/features/seances/seances_store.dart';

const _dbName = 'studymate_calendar_test.db';
const _alex = SeanceUser(
  id: 'user-ab',
  displayName: 'Alex Benali',
  initials: 'AB',
);
const _events = '/calendar/v3/calendars/primary/events';

Seance _seance({
  TimeOfDay start = const TimeOfDay(hour: 17, minute: 0),
  TimeOfDay end = const TimeOfDay(hour: 18, minute: 30),
}) {
  return Seance(
    id: 'flutter',
    ownerId: 'user-ab',
    subject: 'Flutter',
    title: 'Révisions Flutter & Dart',
    host: 'Alex Benali',
    date: DateTime(2026, 10, 11),
    start: start,
    end: end,
    format: SessionFormat.online,
    place: 'https://meet.google.com/abc-defg-hij',
    seatsLeft: 6,
  );
}

http.Response _json(Map<String, Object?> body, [int status = 200]) {
  return http.Response(jsonEncode(body), status);
}

class _Recorder {
  _Recorder(this._handler);

  final http.Response Function(http.Request request) _handler;
  final requests = <http.Request>[];

  GoogleCalendarApi api({Future<String> Function()? token}) {
    return GoogleCalendarApi(
      accessToken: token ?? () async => 'token-1',
      onUnauthorized: (_) async {},
      client: _ScriptedClient((request) async {
        requests.add(request);
        return _handler(request);
      }),
    );
  }

  List<String> get calls =>
      requests.map((r) => '${r.method} ${r.url.path}').toList();
}

http.Response _happyPath(http.Request request) {
  return switch (request.method) {
    'GET' => _json({'items': <Object?>[]}),
    'POST' => _json({'id': 'evt-1'}),
    'PATCH' => _json({'id': 'evt-1'}),
    'DELETE' => http.Response('', 204),
    _ => http.Response('{"error":{"message":"nope"}}', 404),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    await deleteDatabase(path);
  });

  group('event content', () {
    test('describes the seance with its real start, end and link', () {
      final body = calendarEventBody(_seance());

      expect(body['summary'], 'Révisions Flutter & Dart');
      expect(body['location'], 'https://meet.google.com/abc-defg-hij');
      expect(body['description'], contains('Alex Benali'));
      expect(body['description'], contains('Flutter'));
      expect(body['status'], 'confirmed');
      expect(
        (body['start'] as Map)['dateTime'],
        DateTime(2026, 10, 11, 17).toUtc().toIso8601String(),
      );
      expect(
        (body['end'] as Map)['dateTime'],
        DateTime(2026, 10, 11, 18, 30).toUtc().toIso8601String(),
      );
      final private = (body['extendedProperties'] as Map)['private'] as Map;
      expect(private['studymateSeanceId'], 'flutter');
    });

    test('a seance that ends after midnight finishes the next day', () {
      final interval = seanceInterval(
        _seance(
          start: const TimeOfDay(hour: 23, minute: 0),
          end: const TimeOfDay(hour: 0, minute: 30),
        ),
      );

      expect(interval.start, DateTime(2026, 10, 11, 23));
      expect(interval.end, DateTime(2026, 10, 12, 0, 30));
    });
  });

  group('Google Calendar API', () {
    test('creates an event once, after checking for an existing one', () async {
      final recorder = _Recorder(_happyPath);
      final id = await recorder.api().upsertSeance(_seance());

      expect(id, 'evt-1');
      expect(recorder.calls, ['GET $_events', 'POST $_events']);
      expect(recorder.requests.first.headers['Authorization'], 'Bearer token-1');
      expect(
        recorder.requests.first.url.queryParameters['privateExtendedProperty'],
        'studymateSeanceId=flutter',
      );
      expect(
        (jsonDecode(recorder.requests.last.body) as Map)['summary'],
        'Révisions Flutter & Dart',
      );
    });

    test('updates the event it already knows instead of duplicating', () async {
      final recorder = _Recorder(_happyPath);
      final id = await recorder.api().upsertSeance(_seance(), eventId: 'evt-1');

      expect(id, 'evt-1');
      expect(recorder.calls, ['PATCH $_events/evt-1']);
    });

    test('reuses an event found by seance id when the id was lost', () async {
      final recorder = _Recorder((request) {
        if (request.method == 'GET') {
          return _json({
            'items': [
              {'id': 'old-9'},
            ],
          });
        }
        return _json({'id': 'old-9'});
      });
      final id = await recorder.api().upsertSeance(_seance());

      expect(id, 'old-9');
      expect(recorder.calls, ['GET $_events', 'PATCH $_events/old-9']);
    });

    test('recreates an event deleted from Google Calendar', () async {
      final recorder = _Recorder((request) {
        if (request.method == 'PATCH') {
          return http.Response('{"error":{"message":"Not Found"}}', 404);
        }
        return _json({'id': 'evt-2'});
      });
      final id = await recorder.api().upsertSeance(_seance(), eventId: 'evt-1');

      expect(id, 'evt-2');
      expect(recorder.calls, ['PATCH $_events/evt-1', 'POST $_events']);
    });

    test('deleting an event that is already gone is not an error', () async {
      final recorder = _Recorder(
        (_) => http.Response('{"error":{"message":"Gone"}}', 410),
      );

      await recorder.api().deleteEvent('evt-1');
      expect(recorder.calls, ['DELETE $_events/evt-1']);
    });

    test('shows the Google message and retries once after a 401', () async {
      var tokens = 0;
      final recorder = _Recorder((request) {
        if (request.headers['Authorization'] == 'Bearer expired') {
          return http.Response('{"error":{"message":"expired"}}', 401);
        }
        return _json({
          'error': {'message': 'Calendar API has not been used'},
        }, 403);
      });
      final api = recorder.api(
        token: () async => tokens++ == 0 ? 'expired' : 'fresh',
      );

      await expectLater(
        api.deleteEvent('evt-1'),
        throwsA(
          isA<CalendarApiException>().having(
            (error) => error.message,
            'message',
            'Calendar API has not been used',
          ),
        ),
      );
      expect(recorder.requests, hasLength(2));
    });
  });

  group('séances store', () {
    Future<SeancesStore> openStore(_Recorder recorder) async {
      final store = SeancesStore(
        database: SeancesDatabase(fileName: _dbName),
        loadUser: () async => _alex,
        calendar: recorder.api(),
      );
      await store.load();
      return store;
    }

    test('adds an owned seance to the calendar and removes it again', () async {
      final recorder = _Recorder(_happyPath);
      final store = await openStore(recorder);

      final added = await store.toggleCalendar('flutter');
      expect(added.ok, isTrue);
      var flutter = store.items.firstWhere((s) => s.id == 'flutter');
      expect(flutter.calendarEventId, 'evt-1');

      // La base garde l'identifiant : un nouveau store le retrouve.
      final reopened = await openStore(_Recorder(_happyPath));
      flutter = reopened.items.firstWhere((s) => s.id == 'flutter');
      expect(flutter.inCalendar, isTrue);

      final removed = await store.toggleCalendar('flutter');
      expect(removed.ok, isTrue);
      flutter = store.items.firstWhere((s) => s.id == 'flutter');
      expect(flutter.inCalendar, isFalse);
      expect(recorder.calls.last, 'DELETE $_events/evt-1');
    });

    test('refuses a seance that is neither owned nor reserved', () async {
      final recorder = _Recorder(_happyPath);
      final store = await openStore(recorder);
      final foreign = store.items.firstWhere(
        (s) => !store.isOwner(s) && !s.reserved,
      );

      final result = await store.toggleCalendar(foreign.id);

      expect(result.ok, isFalse);
      expect(recorder.requests, isEmpty);
    });

    test('keeps the seance out of the calendar when Google refuses', () async {
      final recorder = _Recorder(
        (_) => _json({
          'error': {'message': 'Accès refusé'},
        }, 403),
      );
      final store = await openStore(recorder);

      final result = await store.toggleCalendar('flutter');

      expect(result.ok, isFalse);
      expect(result.message, 'Accès refusé');
      expect(
        store.items.firstWhere((s) => s.id == 'flutter').inCalendar,
        isFalse,
      );
      expect(store.isCalendarBusy('flutter'), isFalse);
    });

    test('editing a synced seance updates its event', () async {
      final recorder = _Recorder(_happyPath);
      final store = await openStore(recorder);
      await store.toggleCalendar('flutter');
      recorder.requests.clear();

      final mine = store.items.firstWhere((s) => s.id == 'flutter');
      expect(await store.update(mine.copyWith(title: 'Nouveau titre')), isTrue);

      expect(recorder.calls, ['PATCH $_events/evt-1']);
      expect(
        (jsonDecode(recorder.requests.single.body) as Map)['summary'],
        'Nouveau titre',
      );
      expect(store.takeCalendarWarning(), isNull);
    });

    test('a calendar failure after an edit becomes a warning', () async {
      var failing = false;
      final recorder = _Recorder((request) {
        if (failing) {
          return _json({
            'error': {'message': 'Hors ligne'},
          }, 503);
        }
        return _happyPath(request);
      });
      final store = await openStore(recorder);
      await store.toggleCalendar('flutter');
      failing = true;

      final mine = store.items.firstWhere((s) => s.id == 'flutter');
      expect(await store.update(mine.copyWith(title: 'Autre')), isTrue);

      expect(store.takeCalendarWarning(), contains('Hors ligne'));
      expect(store.takeCalendarWarning(), isNull);
      expect(
        store.items.firstWhere((s) => s.id == 'flutter').title,
        'Autre',
      );
    });

    test('deleting a synced seance deletes its event', () async {
      final recorder = _Recorder(_happyPath);
      final store = await openStore(recorder);
      await store.toggleCalendar('flutter');
      recorder.requests.clear();

      expect(await store.delete('flutter'), isTrue);

      expect(recorder.calls, ['DELETE $_events/evt-1']);
      expect(store.items.any((s) => s.id == 'flutter'), isFalse);
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
