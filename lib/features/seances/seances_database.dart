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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE seances (
            id TEXT PRIMARY KEY,
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
        ''');
        for (final seance in _sampleSeances) {
          await db.insert('seances', seance.toMap());
        }
      },
    );
  }
}

final _sampleSeances = <Seance>[
  Seance(
    id: 'docker',
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
