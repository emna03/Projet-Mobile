import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studymate/features/availability/availability_models.dart';
import 'package:studymate/features/availability/common_slots.dart';
import 'package:studymate/features/availability/demo_data.dart';
import 'package:studymate/features/seances/seance_user.dart';
import 'package:studymate/features/seances/seances_database.dart';
import 'package:studymate/features/seances/seances_store.dart';

const _dbName = 'studymate_availability_test.db';
const _alex = SeanceUser(
  id: 'user-ab',
  displayName: 'Alex Benali',
  initials: 'AB',
);

/// Mardi 10 novembre 2026, 09:00.
final _now = DateTime(2026, 11, 10, 9);

AvailabilityWindow _w(int day, int from, int to) =>
    AvailabilityWindow(weekday: day, startMinutes: from, endMinutes: to);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    await deleteDatabase(path);
  });

  Future<SeancesStore> openStore() async {
    final store = SeancesStore(
      database: SeancesDatabase(fileName: _dbName),
      loadUser: () async => _alex,
    );
    await store.load();
    return store;
  }

  group('demo data', () {
    test('builds four upcoming seances owned by the user', () {
      final data = buildDemoData(
        now: _now,
        ownerId: 'user-ab',
        ownerName: 'Alex Benali',
      );

      expect(data.seances.map((s) => s.id), [
        'demo-algo',
        'demo-sql',
        'demo-reseaux',
        'demo-flutter',
      ]);
      expect(data.seances.every((s) => s.ownerId == 'user-ab'), isTrue);
      expect(data.seances.every((s) => s.host == 'Alex Benali'), isTrue);
      expect(data.seances.map((s) => s.date), [
        DateTime(2026, 11, 12),
        DateTime(2026, 11, 13),
        DateTime(2026, 11, 14),
        DateTime(2026, 11, 15),
      ]);
      expect(data.users.map((u) => u.name).toSet(), {
        'Sarah Ben Ali',
        'Yassine Trabelsi',
        'Ines Gharbi',
        'Amine Khaled',
      });
      expect(data.users.every((u) => isDemoId(u.id)), isTrue);
      expect(
        data.users.every((u) => u.email.endsWith('@studymate.test')),
        isTrue,
      );
    });
  });

  group('séances store', () {
    test('loads the examples with participants and availabilities', () async {
      final store = await openStore();
      final before = store.items.length;
      expect(store.hasDemoData, isFalse);

      expect(await store.loadDemoData(now: _now), isTrue);

      expect(store.hasDemoData, isTrue);
      expect(store.items.length, before + 4);

      final participants = await store.participantsFor('demo-algo');
      expect(participants.map((p) => p.name), [
        'Alex Benali',
        'Sarah Ben Ali',
        'Yassine Trabelsi',
        'Ines Gharbi',
      ]);
      expect(participants.first.isMe, isTrue);
      expect(participants.first.windows, isNotEmpty);
      expect(
        participants.skip(1).every((p) => p.windows.isNotEmpty),
        isTrue,
      );
    });

    test('the demo participants give the expected common slot', () async {
      final store = await openStore();
      await store.loadDemoData(now: _now);

      final participants = await store.participantsFor('demo-algo');
      final slots = proposeSlots(
        participants: participants,
        duration: const Duration(minutes: 90),
        from: _now,
      );

      final first = slots.firstWhere((s) => s.everyone);
      expect(first.start, DateTime(2026, 11, 11, 18));
    });

    test('keeps the availability the user already had', () async {
      final store = await openStore();
      final mine = [_w(DateTime.sunday, 600, 720)];
      await store.saveAvailability(_alex.id, mine);

      await store.loadDemoData(now: _now);

      final participants = await store.participantsFor('demo-sql');
      expect(participants.first.windows, mine);
    });

    test('loading twice does not duplicate anything', () async {
      final store = await openStore();
      await store.loadDemoData(now: _now);
      final count = store.items.length;

      await store.loadDemoData(now: _now);

      expect(store.items.length, count);
      expect((await store.participantsFor('demo-flutter')), hasLength(5));
    });

    test('clearing removes only the examples', () async {
      final store = await openStore();
      final real = store.items.map((s) => s.id).toSet();
      final mine = [_w(DateTime.monday, 600, 720)];
      await store.saveAvailability(_alex.id, mine);
      await store.loadDemoData(now: _now);

      await store.clearDemoData();

      expect(store.hasDemoData, isFalse);
      expect(store.items.map((s) => s.id).toSet(), real);
      expect((await store.participantsFor('demo-algo')).length, 1);
      // Mes disponibilités ne font pas partie des exemples.
      expect((await store.participantsFor('x')).first.windows, mine);
    });

    test('saves and reads back an availability', () async {
      final store = await openStore();

      await store.saveAvailability(_alex.id, [
        _w(DateTime.wednesday, 17 * 60, 19 * 60),
        _w(DateTime.wednesday, 18 * 60, 20 * 60),
        _w(DateTime.saturday, 10 * 60, 12 * 60),
      ]);

      final windows = (await store.participantsFor('flutter')).first.windows;
      expect(windows, [
        _w(DateTime.wednesday, 17 * 60, 20 * 60),
        _w(DateTime.saturday, 10 * 60, 12 * 60),
      ]);
    });

    test('adds and removes a participant added by hand', () async {
      final store = await openStore();

      final added = await store.addParticipant('flutter', '  Nour Hamdi ');
      await store.saveAvailability(added.id, [
        _w(DateTime.friday, 14 * 60, 18 * 60),
      ]);

      var list = await store.participantsFor('flutter');
      expect(list.map((p) => p.name), ['Alex Benali', 'Nour Hamdi']);
      expect(list.last.windows, hasLength(1));

      await store.removeParticipant('flutter', added.id);
      list = await store.participantsFor('flutter');
      expect(list, hasLength(1));
    });

    test('deleting a seance deletes its participants', () async {
      final store = await openStore();
      await store.addParticipant('flutter', 'Nour Hamdi');

      expect(await store.delete('flutter'), isTrue);

      expect((await store.participantsFor('flutter')), hasLength(1));
    });

    test('a signed-out user cannot load the examples', () async {
      final store = SeancesStore(
        database: SeancesDatabase(fileName: _dbName),
        loadUser: () async => SeanceUser.anonymous,
      );
      await store.load();

      expect(await store.loadDemoData(now: _now), isFalse);
      expect(store.hasDemoData, isFalse);
    });
  });
}
