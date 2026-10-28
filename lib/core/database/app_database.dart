import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'database_migrations.dart';

/// Singleton wrapper around the sqflite [Database] instance.
///
/// Usage:
/// ```dart
/// final db = await AppDatabase.instance.database;
/// ```
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _kDbName = 'studymate.db';
  // Bumped to 2 to trigger chat-tables migration on existing installs.
  static const _kVersion = 2;

  Database? _db;

  /// Returns the open database, lazily initialising it on first access.
  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbsPath = await getDatabasesPath();
    final path = join(dbsPath, _kDbName);

    return openDatabase(
      path,
      version: _kVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  /// Enable foreign-key enforcement (must be done per-connection).
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await DatabaseMigrations.createSchema(db);
    await DatabaseMigrations.seedInitialData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await DatabaseMigrations.migrateV1toV2(db);
  }

  /// Closes the database connection (useful in tests).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
