import 'package:sqflite/sqflite.dart';

import '../models/quiz_attempt.dart';
import 'quiz_local_database.dart';

class QuizAttemptRepository {
  QuizAttemptRepository({Database? database}) : _dbOverride = database;

  final Database? _dbOverride;

  Future<Database> get _db async =>
      _dbOverride ?? await QuizLocalDatabase.instance.database;

  Future<void> save(QuizAttempt attempt) async {
    final db = await _db;
    await db.insert(
      'quiz_attempts',
      attempt.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<QuizAttempt>> listForUser(String userId) async {
    final db = await _db;
    final rows = await db.query(
      'quiz_attempts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'completed_at DESC',
    );
    return rows.map(QuizAttempt.fromMap).toList();
  }

  Future<List<QuizAttempt>> listForQuiz({
    required String userId,
    required String quizId,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'quiz_attempts',
      where: 'user_id = ? AND quiz_id = ?',
      whereArgs: [userId, quizId],
      orderBy: 'completed_at DESC',
    );
    return rows.map(QuizAttempt.fromMap).toList();
  }

  Future<void> updateAnalysis({
    required String attemptId,
    required String analysisJson,
  }) async {
    final db = await _db;
    await db.update(
      'quiz_attempts',
      {'ai_analysis_json': analysisJson},
      where: 'id = ?',
      whereArgs: [attemptId],
    );
  }

  /// Progression déterministe entre la dernière et l'avant-dernière tentative du même quiz.
  int? progressDeltaPercent({
    required List<QuizAttempt> attemptsForQuiz,
  }) {
    if (attemptsForQuiz.length < 2) return null;
    return attemptsForQuiz[0].scorePercent - attemptsForQuiz[1].scorePercent;
  }
}
