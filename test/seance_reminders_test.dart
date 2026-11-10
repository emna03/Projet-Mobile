import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studymate/features/notifications/notifications_sheet.dart';
import 'package:studymate/features/notifications/seance_reminders.dart';
import 'package:studymate/features/seances/seances_page.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/features/seances/seance_user.dart';
import 'package:studymate/features/seances/seances_database.dart';
import 'package:studymate/features/seances/seances_store.dart';

const _dbName = 'studymate_reminders_test.db';
const _alex = SeanceUser(
  id: 'user-ab',
  displayName: 'Alex Benali',
  initials: 'AB',
);

/// Les séances d'exemple datent d'octobre 2026 : on se place juste avant.
final _now = DateTime(2026, 10, 1, 9);

Seance _seance({
  String id = 'docker',
  String title = 'Docker, de zéro à déployé',
  DateTime? date,
  TimeOfDay start = const TimeOfDay(hour: 18, minute: 0),
  SessionFormat format = SessionFormat.online,
  String place = 'https://meet.google.com/abc-defg-hij',
}) {
  return Seance(
    id: id,
    ownerId: 'user-yassine',
    subject: 'Docker',
    title: title,
    host: 'Yassine Trabelsi',
    date: date ?? DateTime(2026, 10, 7),
    start: start,
    end: const TimeOfDay(hour: 19, minute: 30),
    format: format,
    place: place,
    seatsLeft: 4,
    reserved: true,
  );
}

class _FakePhone implements ReminderBackend {
  bool available = true;
  bool failing = false;
  bool enabled = true;
  bool grantOnRequest = true;
  int permissionRequests = 0;
  final shown = <String>[];
  final scheduled = <int, SeanceReminder>{};
  final cancelled = <int>[];

  @override
  Future<bool> ensureReady() async => available;

  @override
  Future<void> requestPermission() async {
    permissionRequests++;
    if (grantOnRequest) enabled = true;
  }

  @override
  Future<bool> notificationsEnabled() async => enabled;

  @override
  Future<void> showNow(String title, String body) async => shown.add(title);

  @override
  Future<Set<int>> pendingIds() async {
    if (failing) throw StateError('plugin indisponible');
    return scheduled.keys.toSet();
  }

  @override
  Future<void> schedule(SeanceReminder reminder) async {
    scheduled[reminder.id] = reminder;
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
    cancelled.add(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    await deleteDatabase(path);
  });

  group('buildReminders', () {
    test('reminds 30 minutes before, with time, host and place', () {
      final reminder = buildReminders([_seance()], now: _now).single;

      expect(reminder.when, DateTime(2026, 10, 7, 17, 30));
      expect(reminder.title, 'Séance dans 30 min : Docker, de zéro à déployé');
      expect(reminder.body, '18:00 – 19:30 · Avec Yassine Trabelsi · Google Meet');
      expect(reminder.id, reminderId('docker'));
    });

    test('names the room of an in-person seance', () {
      final reminder = buildReminders([
        _seance(format: SessionFormat.inPerson, place: 'Salle B12'),
      ], now: _now).single;

      expect(reminder.body, endsWith('Salle B12'));
    });

    test('skips seances whose reminder time has passed', () {
      final reminders = buildReminders(
        [
          _seance(id: 'past', date: DateTime(2026, 9, 20)),
          // Commence dans 20 min : l'heure du rappel est déjà passée.
          _seance(id: 'soon', date: DateTime(2026, 10, 1),
              start: const TimeOfDay(hour: 9, minute: 20)),
          _seance(id: 'later', date: DateTime(2026, 10, 1),
              start: const TimeOfDay(hour: 9, minute: 31)),
        ],
        now: _now,
      );

      expect(reminders.map((r) => r.id), [reminderId('later')]);
    });

    test('sorts by time and keeps ids stable and distinct', () {
      final reminders = buildReminders(
        [
          _seance(id: 'b', date: DateTime(2026, 10, 9)),
          _seance(id: 'a', date: DateTime(2026, 10, 8)),
        ],
        now: _now,
      );

      expect(reminders.map((r) => r.id), [reminderId('a'), reminderId('b')]);
      expect(reminderId('a'), isNot(reminderId('b')));
      expect(reminderId('flutter'), reminderId('flutter'));
      expect(reminderId('1794251330814000'), inInclusiveRange(0, 0x7fffffff));
    });
  });

  group('SeanceReminders.sync', () {
    test('schedules new reminders and asks permission only once', () async {
      final phone = _FakePhone();
      final reminders = SeanceReminders(backend: phone, clock: () => _now);

      await reminders.sync([_seance()]);
      await reminders.sync([_seance(), _seance(id: 'git')]);

      expect(phone.scheduled.keys, {reminderId('docker'), reminderId('git')});
      expect(phone.permissionRequests, 1);
      expect(phone.cancelled, isEmpty);
    });

    test('cancels reminders of seances that are gone', () async {
      final phone = _FakePhone();
      final reminders = SeanceReminders(backend: phone, clock: () => _now);
      await reminders.sync([_seance(), _seance(id: 'git')]);

      await reminders.sync([_seance(id: 'git')]);

      expect(phone.scheduled.keys, {reminderId('git')});
      expect(phone.cancelled, [reminderId('docker')]);
    });

    test('moves the reminder when the seance time changes', () async {
      final phone = _FakePhone();
      final reminders = SeanceReminders(backend: phone, clock: () => _now);
      await reminders.sync([_seance()]);

      await reminders.sync([
        _seance(start: const TimeOfDay(hour: 20, minute: 0)),
      ]);

      expect(phone.scheduled, hasLength(1));
      expect(
        phone.scheduled[reminderId('docker')]!.when,
        DateTime(2026, 10, 7, 19, 30),
      );
    });

    test('does not ask permission when there is nothing to remind', () async {
      final phone = _FakePhone();
      final reminders = SeanceReminders(backend: phone, clock: () => _now);

      await reminders.sync([_seance(date: DateTime(2026, 9, 1))]);

      expect(phone.permissionRequests, 0);
      expect(phone.scheduled, isEmpty);
    });

    test('does nothing where notifications are unavailable', () async {
      final phone = _FakePhone()..available = false;
      final reminders = SeanceReminders(backend: phone, clock: () => _now);

      await reminders.sync([_seance()]);

      expect(phone.scheduled, isEmpty);
      expect(phone.permissionRequests, 0);
    });

    test('a failing phone never throws to the caller', () async {
      final phone = _FakePhone()..failing = true;
      final reminders = SeanceReminders(backend: phone, clock: () => _now);

      await reminders.sync([_seance()]);

      expect(phone.scheduled, isEmpty);
    });
  });

  group('séances store', () {
    late _FakePhone phone;

    Future<SeancesStore> openStore() async {
      phone = _FakePhone();
      final store = SeancesStore(
        database: SeancesDatabase(fileName: _dbName),
        loadUser: () async => _alex,
        reminders: SeanceReminders(backend: phone, clock: () => _now),
      );
      await store.load();
      return store;
    }

    test('reminds for owned and reserved seances only', () async {
      final store = await openStore();

      final concerned = store.items.where(store.canSyncCalendar).toList();
      expect(concerned, isNotEmpty);
      expect(concerned.length, lessThan(store.items.length));
      expect(phone.scheduled.keys, {
        for (final seance in concerned) reminderId(seance.id),
      });
    });

    test('reserving adds a reminder and cancelling removes it', () async {
      final store = await openStore();
      final other = store.items.firstWhere(
        (s) => !store.canSyncCalendar(s) && s.seatsLeft > 0,
      );

      await store.toggleReservation(other.id);
      expect(phone.scheduled.keys, contains(reminderId(other.id)));

      await store.toggleReservation(other.id);
      expect(phone.scheduled.keys, isNot(contains(reminderId(other.id))));
      expect(phone.cancelled, contains(reminderId(other.id)));
    });

    test('deleting an owned seance cancels its reminder', () async {
      final store = await openStore();
      expect(phone.scheduled.keys, contains(reminderId('flutter')));

      expect(await store.delete('flutter'), isTrue);

      expect(phone.scheduled.keys, isNot(contains(reminderId('flutter'))));
    });

    test('editing an owned seance moves its reminder', () async {
      final store = await openStore();
      final mine = store.items.firstWhere((s) => s.id == 'flutter');

      expect(
        await store.update(
          mine.copyWith(start: const TimeOfDay(hour: 8, minute: 0)),
        ),
        isTrue,
      );

      final reminder = phone.scheduled[reminderId('flutter')]!;
      expect(reminder.when.hour, 7);
      expect(reminder.when.minute, 30);
    });
  });

  group('upcomingAlerts', () {
    test('lists seances that have not started, nearest first', () {
      final alerts = upcomingAlerts(
        [
          _seance(id: 'later', date: DateTime(2026, 10, 9)),
          _seance(id: 'past', date: DateTime(2026, 9, 20)),
          _seance(id: 'soon', date: DateTime(2026, 10, 7)),
        ],
        now: _now,
      );

      expect(alerts.map((a) => a.seance.id), ['soon', 'later']);
      expect(alerts.first.remindAt, DateTime(2026, 10, 7, 17, 30));
      expect(alerts.first.sent, isFalse);
    });

    test('marks a reminder as sent once its time has passed', () {
      final alert = upcomingAlerts(
        [_seance()],
        now: DateTime(2026, 10, 7, 17, 45),
      ).single;

      expect(alert.sent, isTrue);
    });

    test('ignores a seance that already started', () {
      final alerts = upcomingAlerts(
        [_seance()],
        now: DateTime(2026, 10, 7, 18, 30),
      );

      expect(alerts, isEmpty);
    });
  });

  group('notification state', () {
    test('reports whether notifications are allowed', () async {
      final phone = _FakePhone()..enabled = false;
      final reminders = SeanceReminders(backend: phone, clock: () => _now);

      expect(await reminders.notificationsEnabled(), isFalse);
      phone.enabled = true;
      expect(await reminders.notificationsEnabled(), isTrue);
    });

    test('asks the user and reports the answer', () async {
      final phone = _FakePhone()..enabled = false;
      final reminders = SeanceReminders(backend: phone, clock: () => _now);

      expect(await reminders.enableNotifications(), isTrue);
      expect(phone.permissionRequests, 1);

      final refused = _FakePhone()
        ..enabled = false
        ..grantOnRequest = false;
      expect(
        await SeanceReminders(backend: refused).enableNotifications(),
        isFalse,
      );
    });

    test('sends a test only when notifications are allowed', () async {
      final phone = _FakePhone();
      final reminders = SeanceReminders(backend: phone, clock: () => _now);

      expect(await reminders.sendTest(), isTrue);
      expect(phone.shown, ['Notification de test']);

      phone.enabled = false;
      expect(await reminders.sendTest(), isFalse);
      expect(phone.shown, hasLength(1));
    });

    test('a failing phone never throws from the state helpers', () async {
      final phone = _FakePhone()..available = false;
      final reminders = SeanceReminders(backend: phone, clock: () => _now);

      expect(await reminders.notificationsEnabled(), isFalse);
      expect(await reminders.enableNotifications(), isFalse);
      expect(await reminders.sendTest(), isFalse);
    });
  });

  group('notifications panel', () {
    late _FakePhone phone;

    Future<SeancesStore> openStore() async {
      phone = _FakePhone();
      final store = SeancesStore(
        database: SeancesDatabase(fileName: _dbName),
        loadUser: () async => _alex,
        reminders: SeanceReminders(backend: phone, clock: () => _now),
      );
      await store.load();
      return store;
    }

    Future<void> showSheet(WidgetTester tester, SeancesStore store) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationsSheet(store: store, clock: () => _now),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists the upcoming seances with their reminder time', (
      tester,
    ) async {
      final store = (await tester.runAsync(openStore))!;
      await showSheet(tester, store);

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Notifications activées'), findsOneWidget);
      expect(find.text('Séances à venir'), findsOneWidget);
      // Docker (18:00) est réservée et Flutter (17:00) appartient à Alex.
      expect(find.text('Docker, de zéro à déployé'), findsOneWidget);
      expect(find.text('Rappel à 17:30'), findsOneWidget);
      expect(find.text('Révisions Flutter & Dart'), findsOneWidget);
      expect(find.text('Rappel à 16:30'), findsOneWidget);
    });

    testWidgets('sends a test notification', (tester) async {
      final store = (await tester.runAsync(openStore))!;
      await showSheet(tester, store);

      await tester.tap(find.text('Envoyer un test'));
      await tester.pumpAndSettle();

      expect(phone.shown, ['Notification de test']);
      expect(
        find.textContaining('Notification de test envoyée'),
        findsOneWidget,
      );
    });

    testWidgets('offers to enable notifications when they are off', (
      tester,
    ) async {
      final store = (await tester.runAsync(openStore))!;
      phone.enabled = false;
      await showSheet(tester, store);

      expect(find.text('Notifications désactivées'), findsOneWidget);
      expect(find.text('Activer'), findsOneWidget);

      await tester.tap(find.text('Activer'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      expect(phone.permissionRequests, greaterThanOrEqualTo(1));
      expect(find.text('Notifications activées'), findsOneWidget);
      expect(find.text('Activer'), findsNothing);
    });

    testWidgets('explains how to enable them after a refusal', (tester) async {
      final store = (await tester.runAsync(openStore))!;
      phone
        ..enabled = false
        ..grantOnRequest = false;
      await showSheet(tester, store);

      await tester.tap(find.text('Activer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Autorisation refusée'), findsOneWidget);
      expect(find.text('Notifications désactivées'), findsOneWidget);
    });

    testWidgets('the bell on the séances page opens the panel', (tester) async {
      final store = (await tester.runAsync(openStore))!;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SeancesPage(store: store))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Séances à venir'), findsOneWidget);
      expect(find.text('Envoyer un test'), findsOneWidget);
    });
  });
}
