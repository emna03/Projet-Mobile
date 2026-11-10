import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Base SQLite dédiée au module Quiz.
/// Fichier séparé de `studymate.db` (profils) — migrations non destructives.
class QuizLocalDatabase {
  QuizLocalDatabase._();
  static final QuizLocalDatabase instance = QuizLocalDatabase._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _open();
    return _database!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'studymate_quiz.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _createV1(db);
        await _createV2(db);
        await _createV3(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createV2(db);
        }
        if (oldVersion < 3) {
          await _createV3(db);
        }
      },
    );
  }

  Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_attempts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        quiz_id TEXT NOT NULL,
        quiz_title TEXT NOT NULL,
        subject TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        correct_count INTEGER NOT NULL,
        total_count INTEGER NOT NULL,
        selected_answers TEXT NOT NULL,
        completed_at TEXT NOT NULL,
        source TEXT NOT NULL,
        ai_analysis_json TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user ON quiz_attempts(user_id, completed_at DESC)',
    );
  }

  Future<void> _createV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quizzes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        subject TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        estimated_minutes INTEGER NOT NULL,
        generated_by_ai INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_questions (
        id TEXT PRIMARY KEY,
        quiz_id TEXT NOT NULL,
        text TEXT NOT NULL,
        options_json TEXT NOT NULL,
        correct_index INTEGER NOT NULL,
        explanation TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        FOREIGN KEY (quiz_id) REFERENCES quizzes(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quiz_questions_quiz ON quiz_questions(quiz_id, sort_order)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_results (
        id TEXT PRIMARY KEY,
        quiz_id TEXT NOT NULL,
        quiz_title TEXT NOT NULL,
        subject TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        date_label TEXT NOT NULL,
        correct_count INTEGER NOT NULL,
        total_count INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Knowledge Graph — tables isolées, non destructives.
  Future<void> _createV3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kg_concepts (
        id TEXT PRIMARY KEY,
        canonical_name TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        subject TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kg_edges (
        id TEXT PRIMARY KEY,
        from_concept_id TEXT NOT NULL,
        to_concept_id TEXT NOT NULL,
        relation_type TEXT NOT NULL,
        weight REAL NOT NULL DEFAULT 1.0,
        justification TEXT NOT NULL DEFAULT '',
        UNIQUE(from_concept_id, to_concept_id, relation_type)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kg_question_concepts (
        id TEXT PRIMARY KEY,
        question_id TEXT NOT NULL,
        quiz_id TEXT NOT NULL,
        concept_id TEXT NOT NULL,
        weight REAL NOT NULL DEFAULT 1.0,
        skill_label TEXT NOT NULL DEFAULT '',
        UNIQUE(question_id, concept_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kg_student_mastery (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        concept_id TEXT NOT NULL,
        score_percent REAL NOT NULL,
        level TEXT NOT NULL,
        correct_weight REAL NOT NULL,
        total_weight REAL NOT NULL,
        attempt_count INTEGER NOT NULL,
        distinct_questions INTEGER NOT NULL,
        last_attempt_at TEXT,
        updated_at TEXT NOT NULL,
        UNIQUE(user_id, concept_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kg_extraction_cache (
        quiz_id TEXT PRIMARY KEY,
        content_hash TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        source TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_kg_mastery_user ON kg_student_mastery(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_kg_qc_quiz ON kg_question_concepts(quiz_id)',
    );
  }

  /// Pour les tests unitaires (injection).
  static void debugSetDatabase(Database? db) {
    _database = db;
  }
}
