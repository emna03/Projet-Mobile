import 'package:sqflite/sqflite.dart';

import 'database_factory.dart';

class AppDatabase {
  AppDatabase._();
  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final path = await databasePath();
    _db = await openDatabase(
      path,
      version: 6,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE resources (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        subject TEXT NOT NULL,
        author TEXT NOT NULL,
        owner_name TEXT NOT NULL,
        content TEXT NOT NULL,
        visibility TEXT NOT NULL,
        group_id TEXT,
        group_name TEXT,
        is_free INTEGER NOT NULL,
        price REAL NOT NULL DEFAULT 0,
        pages INTEGER NOT NULL DEFAULT 1,
        summary TEXT,
        pdf_path TEXT,
        pdf_name TEXT,
        pdf_bytes BLOB,
        created_at INTEGER NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE flashcards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        resource_id INTEGER NOT NULL,
        question TEXT NOT NULL,
        answer TEXT NOT NULL,
        FOREIGN KEY (resource_id) REFERENCES resources (id) ON DELETE CASCADE
      )
    ''');
    await _seed(db);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE resources ADD COLUMN pdf_path TEXT');
      await db.execute('ALTER TABLE resources ADD COLUMN pdf_name TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE resources ADD COLUMN pdf_bytes BLOB');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE resources ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 5) {
      // Bases déjà en v4 créées avant l'ajout de is_favorite : la colonne
      // peut manquer même si onUpgrade < 4 ne s'est pas déclenché.
      final cols = await db.rawQuery('PRAGMA table_info(resources)');
      final has = cols.any((c) => c['name'] == 'is_favorite');
      if (!has) {
        await db.execute('ALTER TABLE resources ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0');
      }
    }
    if (oldVersion < 6) {
      // Le fichier est déjà sur disque : le BLOB dupliqué faisait dépasser
      // la CursorWindow SQLite (2 Mo) sur Android.
      await db.execute(
        "UPDATE resources SET pdf_bytes = NULL WHERE pdf_path IS NOT NULL AND pdf_path != ''",
      );
    }
  }

  static Future<void> _seed(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = [
      {
        'title': 'Cours Java',
        'subject': 'Java',
        'author': 'Nacef Jouini',
        'owner_name': 'Nacef Jouini',
        'content':
            'Java est un langage orienté objet. Une classe décrit un type. Les objets encapsulent état et comportement. Les collections List et Map structurent les données. JVM exécute le bytecode. Les exceptions gèrent les erreurs. Les interfaces définissent des contrats.',
        'visibility': 'public',
        'group_id': null,
        'group_name': null,
        'is_free': 1,
        'price': 0.0,
        'pages': 28,
        'summary': null,
        'created_at': now,
      },
      {
        'title': 'Cours Spring Boot',
        'subject': 'Spring Boot',
        'author': 'Sarah Ben Ali',
        'owner_name': 'Sarah Ben Ali',
        'content':
            'Spring Boot accélère la création d’API REST. @RestController expose des endpoints. @Service contient la logique métier. application.properties configure le serveur. Spring Data JPA persiste les entités. Un starter web embarque Tomcat.',
        'visibility': 'public',
        'group_id': null,
        'group_name': null,
        'is_free': 0,
        'price': 12.0,
        'pages': 24,
        'summary': null,
        'created_at': now,
      },
      {
        'title': 'Notes personnelles',
        'subject': 'Révision',
        'author': 'Nacef Jouini',
        'owner_name': 'Nacef Jouini',
        'content':
            'Mes notes : revoir les annotations Spring, les commandes Docker build et run, et le rôle d’une API Gateway dans une architecture microservices.',
        'visibility': 'private',
        'group_id': null,
        'group_name': null,
        'is_free': 1,
        'price': 0.0,
        'pages': 6,
        'summary': null,
        'created_at': now,
      },
      {
        'title': 'Docker en pratique',
        'subject': 'Docker',
        'author': 'Yassine Trabelsi',
        'owner_name': 'Yassine Trabelsi',
        'content':
            'Docker empaquette une application dans une image. Un Dockerfile décrit le build. docker build crée l’image. docker run lance un conteneur. docker-compose orchestre plusieurs services. Les volumes persistent les données.',
        'visibility': 'group',
        'group_id': 'g2',
        'group_name': 'Docker & DevOps',
        'is_free': 1,
        'price': 0.0,
        'pages': 18,
        'summary': null,
        'created_at': now,
      },
      {
        'title': 'Architecture microservices',
        'subject': 'Microservices',
        'author': 'Ines Haddad',
        'owner_name': 'Ines Haddad',
        'content':
            'Les microservices découpent le métier en services autonomes. L’API Gateway route les requêtes. Chaque service a sa base. La découverte de services et le tracing facilitent l’exploitation. La cohérence éventuelle remplace souvent les transactions globales.',
        'visibility': 'public',
        'group_id': null,
        'group_name': null,
        'is_free': 0,
        'price': 18.0,
        'pages': 42,
        'summary': null,
        'created_at': now,
      },
    ];
    for (final row in rows) {
      await db.insert('resources', row);
    }
  }
}
