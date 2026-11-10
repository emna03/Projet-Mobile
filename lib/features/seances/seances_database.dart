import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:studymate/features/availability/availability_models.dart';
import 'package:studymate/features/availability/demo_data.dart';
import 'package:studymate/features/seances/models/seance.dart';

class SeancesDatabase {
  SeancesDatabase({this.fileName = 'studymate_seances.db'});

  final String fileName;
  Database? _database;
  Future<Database>? _opening;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    final opening = _opening ??= _open();
    try {
      final opened = await opening;
      _database = opened;
      return opened;
    } catch (_) {
      if (identical(_opening, opening)) _opening = null;
      rethrow;
    }
  }

  Future<List<Seance>> readAll() async {
    final db = await database;
    final rows = await db.query('seances', orderBy: 'rowid DESC');
    return rows.map(Seance.fromMap).toList();
  }

  Future<void> insert(Seance seance) async {
    final db = await database;
    await db.insert(
      'seances',
      seance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Seance seance) async {
    final db = await database;
    await db.update(
      'seances',
      seance.toMap(),
      where: 'id = ?',
      whereArgs: [seance.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await database;
    await db.delete('seances', where: 'id = ?', whereArgs: [id]);
    await db.delete(
      'seance_participants',
      where: 'seance_id = ?',
      whereArgs: [id],
    );
  }

  /// Disponibilités hebdomadaires de [userId], triées.
  Future<List<AvailabilityWindow>> readAvailability(String userId) async {
    final db = await database;
    final rows = await db.query(
      'availability',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'weekday, start_minutes',
    );
    return rows.map(AvailabilityWindow.fromMap).toList();
  }

  /// Remplace toutes les disponibilités de [userId] par [windows].
  Future<void> replaceAvailability(
    String userId,
    Iterable<AvailabilityWindow> windows,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await _writeAvailability(txn, userId, windows);
    });
  }

  /// Participants de [seanceId] avec leurs disponibilités.
  Future<List<Participant>> readParticipants(String seanceId) async {
    final db = await database;
    final rows = await db.query(
      'seance_participants',
      where: 'seance_id = ?',
      whereArgs: [seanceId],
      orderBy: 'rowid',
    );
    final participants = <Participant>[];
    for (final row in rows) {
      final userId = row['user_id']! as String;
      participants.add(
        Participant(
          id: userId,
          name: row['name']! as String,
          windows: await readAvailability(userId),
        ),
      );
    }
    return participants;
  }

  Future<void> addParticipant(
    String seanceId,
    String userId,
    String name,
  ) async {
    final db = await database;
    await db.insert('seance_participants', {
      'seance_id': seanceId,
      'user_id': userId,
      'name': name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeParticipant(String seanceId, String userId) async {
    final db = await database;
    await db.delete(
      'seance_participants',
      where: 'seance_id = ? AND user_id = ?',
      whereArgs: [seanceId, userId],
    );
    // Un participant ajouté à la main n'existe que pour cette séance.
    final others = await db.query(
      'seance_participants',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (others.isEmpty && !isDemoId(userId)) {
      await db.delete('availability', where: 'user_id = ?', whereArgs: [userId]);
    }
  }

  /// Ajoute les séances d'exemple, leurs participants et leurs
  /// disponibilités. Les disponibilités de [ownerId] ne sont écrites que si
  /// elles sont vides, pour ne jamais écraser celles de l'utilisateur.
  Future<void> insertDemo(DemoData data, {required String ownerId}) async {
    final db = await database;
    final ownerHasAvailability =
        (await readAvailability(ownerId)).isNotEmpty;
    await db.transaction((txn) async {
      for (final seance in data.seances) {
        await txn.insert(
          'seances',
          seance.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final entry in data.participants.entries) {
        for (final user in entry.value) {
          await txn.insert('seance_participants', {
            'seance_id': entry.key,
            'user_id': user.id,
            'name': user.name,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      for (final user in data.users) {
        await _writeAvailability(txn, user.id, user.windows);
      }
      if (!ownerHasAvailability && ownerId.isNotEmpty) {
        await _writeAvailability(txn, ownerId, demoOwnerWindows);
      }
    });
  }

  /// Supprime les séances d'exemple, leurs participants et leurs
  /// disponibilités. Les vraies données ne sont pas touchées.
  Future<void> deleteDemo() async {
    final db = await database;
    const like = '$demoPrefix%';
    await db.transaction((txn) async {
      await txn.delete('seances', where: 'id LIKE ?', whereArgs: [like]);
      await txn.delete(
        'seance_participants',
        where: 'seance_id LIKE ? OR user_id LIKE ?',
        whereArgs: [like, like],
      );
      await txn.delete('availability', where: 'user_id LIKE ?', whereArgs: [like]);
    });
  }

  Future<Database> _open() async {
    final directory = await getDatabasesPath();
    final path = p.join(directory, fileName);
    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute(_createTableSql);
        await _createAvailabilityTables(db);
        for (final seance in _sampleSeances) {
          await db.insert('seances', seance.toMap());
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE seances ADD COLUMN owner_id TEXT NOT NULL DEFAULT ""',
          );
          for (final seance in _sampleSeances) {
            final existing = await db.query(
              'seances',
              where: 'id = ?',
              whereArgs: [seance.id],
            );
            if (existing.isEmpty) {
              await db.insert('seances', seance.toMap());
            } else {
              await db.update(
                'seances',
                {'owner_id': seance.ownerId},
                where: 'id = ?',
                whereArgs: [seance.id],
              );
            }
          }
          final leftover = await db.query(
            'seances',
            where: 'owner_id = ? OR owner_id IS NULL',
            whereArgs: const [''],
          );
          for (final row in leftover) {
            await db.update(
              'seances',
              {'owner_id': _ownerIdForHost(row['host'] as String?)},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE seances ADD COLUMN meet_space_name TEXT',
          );
          await db.execute('ALTER TABLE seances ADD COLUMN meet_code TEXT');
          await db.execute('ALTER TABLE seances ADD COLUMN meet_access TEXT');
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE seances ADD COLUMN calendar_event_id TEXT',
          );
        }
        if (oldVersion < 5) {
          await _createAvailabilityTables(db);
        }
      },
    );
  }
}

Future<void> _createAvailabilityTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS availability (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      weekday INTEGER NOT NULL,
      start_minutes INTEGER NOT NULL,
      end_minutes INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS availability_user ON availability (user_id)',
  );
  await db.execute('''
    CREATE TABLE IF NOT EXISTS seance_participants (
      seance_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      PRIMARY KEY (seance_id, user_id)
    )
  ''');
}

Future<void> _writeAvailability(
  DatabaseExecutor db,
  String userId,
  Iterable<AvailabilityWindow> windows,
) async {
  await db.delete('availability', where: 'user_id = ?', whereArgs: [userId]);
  for (final window in normalizeWindows(windows)) {
    await db.insert('availability', window.toMap(userId));
  }
}

const _createTableSql = '''
  CREATE TABLE seances (
    id TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL,
    subject TEXT NOT NULL,
    title TEXT NOT NULL,
    host TEXT NOT NULL,
    date TEXT NOT NULL,
    start_minutes INTEGER NOT NULL,
    end_minutes INTEGER NOT NULL,
    format TEXT NOT NULL,
    place TEXT NOT NULL,
    seats_left INTEGER NOT NULL,
    reserved INTEGER NOT NULL,
    free INTEGER NOT NULL,
    price_label TEXT,
    meet_space_name TEXT,
    meet_code TEXT,
    meet_access TEXT,
    calendar_event_id TEXT
  )
''';

String _ownerIdForHost(String? host) {
  for (final seance in _sampleSeances) {
    if (seance.host == host) return seance.ownerId;
  }
  return 'user-other';
}

final _sampleSeances = <Seance>[
  Seance(
    id: 'flutter',
    ownerId: 'user-ab',
    subject: 'Flutter',
    title: 'Révisions Flutter & Dart',
    host: 'Alex Benali',
    date: DateTime(2026, 10, 11),
    start: const TimeOfDay(hour: 17, minute: 0),
    end: const TimeOfDay(hour: 18, minute: 30),
    format: SessionFormat.online,
    place: 'Visioconférence',
    seatsLeft: 6,
  ),
  Seance(
    id: 'docker',
    ownerId: 'user-yassine',
    subject: 'Docker',
    title: 'Docker, de zéro à déployé',
    host: 'Yassine Trabelsi',
    date: DateTime(2026, 10, 7),
    start: const TimeOfDay(hour: 18, minute: 0),
    end: const TimeOfDay(hour: 19, minute: 30),
    format: SessionFormat.online,
    place: 'Visioconférence',
    seatsLeft: 4,
    reserved: true,
  ),
  Seance(
    id: 'spring',
    ownerId: 'user-sarah',
    subject: 'Spring Boot',
    title: 'Construire une API Spring Boot',
    host: 'Sarah Ben Ali',
    date: DateTime(2026, 10, 8),
    start: const TimeOfDay(hour: 14, minute: 0),
    end: const TimeOfDay(hour: 16, minute: 0),
    format: SessionFormat.inPerson,
    place: 'Salle B12',
    seatsLeft: 3,
  ),
  Seance(
    id: 'git',
    ownerId: 'user-amine',
    subject: 'Git',
    title: 'Git & GitHub sans stress',
    host: 'Amine Khaled',
    date: DateTime(2026, 10, 9),
    start: const TimeOfDay(hour: 10, minute: 0),
    end: const TimeOfDay(hour: 11, minute: 30),
    format: SessionFormat.online,
    place: 'Visioconférence',
    seatsLeft: 8,
  ),
  Seance(
    id: 'uml',
    ownerId: 'user-ines',
    subject: 'UML',
    title: 'Modéliser un projet avec UML',
    host: 'Ines Gharbi',
    date: DateTime(2026, 10, 10),
    start: const TimeOfDay(hour: 9, minute: 0),
    end: const TimeOfDay(hour: 12, minute: 0),
    format: SessionFormat.inPerson,
    place: 'Salle A3',
    seatsLeft: 2,
  ),
];
