
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

class LocalDatabase {
  LocalDatabase._internal();

  static final LocalDatabase instance = LocalDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'studymate.db');

    debugPrint('BASE STUDYMATE : $path');

    return openDatabase(
      path,
      version: 3,

      // Nouvelle installation
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nom TEXT NOT NULL,
            prenom TEXT NOT NULL,
            telephone TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            role TEXT NOT NULL,
            photoPath TEXT,
            documentUrl TEXT,
            statut TEXT NOT NULL DEFAULT 'active'
          )
        ''');
      },

      // Migration des anciennes versions
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE users_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nom TEXT NOT NULL,
              prenom TEXT NOT NULL,
              telephone TEXT NOT NULL,
              email TEXT NOT NULL UNIQUE,
              role TEXT NOT NULL,
              documentPath TEXT,
              photoPath TEXT,
              statut TEXT NOT NULL DEFAULT 'active'
            )
          ''');

          await db.execute('''
            INSERT INTO users_new
              (id, nom, prenom, telephone, email, role,
               documentPath, photoPath, statut)
            SELECT id, nom, prenom, telephone, email, role,
                   documentPath, photoPath, statut
            FROM users
          ''');

          await db.execute('DROP TABLE users');
          await db.execute('ALTER TABLE users_new RENAME TO users');
        }

        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE users ADD COLUMN documentUrl TEXT',
          );
        }
      },
    );
  }
}
