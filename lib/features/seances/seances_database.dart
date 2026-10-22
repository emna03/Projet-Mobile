import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
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
  }

  Future<Database> _open() async {
    final directory = await getDatabasesPath();
    final path = p.join(directory, fileName);
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute(_createTableSql);
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
      },
    );
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
    price_label TEXT
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
