import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/question.dart';
import '../models/quiz.dart';
import '../models/quiz_result.dart';
import 'quiz_local_database.dart';
import 'quiz_mock_data.dart';

/// Contrat CRUD Quiz (mémoire ou SQLite).
abstract class QuizRepository {
  List<Quiz> getAll();
  Quiz? getById(String id);
  List<QuizResult> getHistory();
  List<String> get subjects;

  Future<void> load();
  Future<Quiz> create(Quiz quiz);
  Future<Quiz> update(Quiz quiz);
  Future<bool> delete(String id);
  Future<void> addResult(QuizResult result);

  /// Repository mémoire (tests / fallback).
  factory QuizRepository.memory({
    List<Quiz>? quizzes,
    List<QuizResult>? history,
  }) = MemoryQuizRepository;

  /// Seeds de démonstration en mémoire.
  factory QuizRepository.seeded() => MemoryQuizRepository();

  /// Persistance SQLite permanente (`studymate_quiz.db`).
  factory QuizRepository.sqlite({Database? database}) = SqliteQuizRepository;
}

class MemoryQuizRepository implements QuizRepository {
  MemoryQuizRepository({
    List<Quiz>? quizzes,
    List<QuizResult>? history,
  })  : _quizzes = List<Quiz>.from(quizzes ?? mockQuizzes),
        _history = List<QuizResult>.from(history ?? mockHistory);

  final List<Quiz> _quizzes;
  final List<QuizResult> _history;
  int _nextId = 1;

  @override
  List<Quiz> getAll() => List.unmodifiable(_quizzes);

  @override
  Quiz? getById(String id) {
    for (final quiz in _quizzes) {
      if (quiz.id == id) return quiz;
    }
    return null;
  }

  @override
  List<QuizResult> getHistory() => List.unmodifiable(_history);

  @override
  List<String> get subjects {
    final values = {for (final quiz in _quizzes) quiz.subject};
    return ['Toutes', ...values];
  }

  @override
  Future<void> load() async {}

  @override
  Future<Quiz> create(Quiz quiz) async {
    final created = quiz.id.isEmpty ? quiz.copyWith(id: _newId()) : quiz;
    if (getById(created.id) != null) {
      final withId = created.copyWith(id: _newId());
      _quizzes.insert(0, withId);
      return withId;
    }
    _quizzes.insert(0, created);
    return created;
  }

  @override
  Future<Quiz> update(Quiz quiz) async {
    final index = _quizzes.indexWhere((item) => item.id == quiz.id);
    if (index < 0) {
      throw StateError('Quiz introuvable : ${quiz.id}');
    }
    _quizzes[index] = quiz;
    return quiz;
  }

  @override
  Future<bool> delete(String id) async {
    final removed = _quizzes.where((quiz) => quiz.id == id).isNotEmpty;
    _quizzes.removeWhere((quiz) => quiz.id == id);
    _history.removeWhere((result) => result.quizId == id);
    return removed;
  }

  @override
  Future<void> addResult(QuizResult result) async {
    _history.insert(0, result);
  }

  String _newId() {
    final id = 'quiz-user-$_nextId-${DateTime.now().millisecondsSinceEpoch}';
    _nextId++;
    return id;
  }
}

/// Persistance permanente quizzes + questions + historique résultats.
class SqliteQuizRepository implements QuizRepository {
  SqliteQuizRepository({Database? database}) : _dbOverride = database;

  final Database? _dbOverride;
  final List<Quiz> _quizzes = [];
  final List<QuizResult> _history = [];
  bool _loaded = false;

  Future<Database> get _db async =>
      _dbOverride ?? await QuizLocalDatabase.instance.database;

  @override
  List<Quiz> getAll() => List.unmodifiable(_quizzes);

  @override
  Quiz? getById(String id) {
    for (final quiz in _quizzes) {
      if (quiz.id == id) return quiz;
    }
    return null;
  }

  @override
  List<QuizResult> getHistory() => List.unmodifiable(_history);

  @override
  List<String> get subjects {
    final values = {for (final quiz in _quizzes) quiz.subject};
    return ['Toutes', ...values];
  }

  @override
  Future<void> load() async {
    final db = await _db;
    final quizRows = await db.query('quizzes', orderBy: 'created_at DESC');
    final loaded = <Quiz>[];

    for (final row in quizRows) {
      final id = row['id'] as String;
      final qRows = await db.query(
        'quiz_questions',
        where: 'quiz_id = ?',
        whereArgs: [id],
        orderBy: 'sort_order ASC',
      );
      final questions = qRows.map(_questionFromRow).toList();
      loaded.add(
        Quiz(
          id: id,
          title: row['title'] as String,
          description: row['description'] as String,
          subject: row['subject'] as String,
          difficulty: quizDifficultyFromName(row['difficulty'] as String?),
          estimatedMinutes: row['estimated_minutes'] as int,
          questions: questions,
          generatedByAi: (row['generated_by_ai'] as int? ?? 0) == 1,
        ),
      );
    }

    if (loaded.isEmpty) {
      // Premier lancement : seed démo puis persiste.
      for (final quiz in mockQuizzes) {
        await _insertQuiz(db, quiz);
        loaded.add(quiz);
      }
    }

    final resultRows =
        await db.query('quiz_results', orderBy: 'created_at DESC');
    _history
      ..clear()
      ..addAll(resultRows.map(_resultFromRow));

    _quizzes
      ..clear()
      ..addAll(loaded);
    _loaded = true;
  }

  Future<void> _ensureLoaded() async {
    if (!_loaded) await load();
  }

  @override
  Future<Quiz> create(Quiz quiz) async {
    await _ensureLoaded();
    final db = await _db;
    final id = quiz.id.isEmpty
        ? 'quiz-${DateTime.now().millisecondsSinceEpoch}'
        : quiz.id;
    final created = quiz.copyWith(id: id);
    await _insertQuiz(db, created);
    _quizzes.insert(0, created);
    return created;
  }

  @override
  Future<Quiz> update(Quiz quiz) async {
    await _ensureLoaded();
    final db = await _db;
    final index = _quizzes.indexWhere((item) => item.id == quiz.id);
    if (index < 0) {
      throw StateError('Quiz introuvable : ${quiz.id}');
    }
    await db.delete('quiz_questions', where: 'quiz_id = ?', whereArgs: [quiz.id]);
    await db.delete('quizzes', where: 'id = ?', whereArgs: [quiz.id]);
    await _insertQuiz(db, quiz);
    _quizzes[index] = quiz;
    return quiz;
  }

  @override
  Future<bool> delete(String id) async {
    await _ensureLoaded();
    final db = await _db;
    final removed = _quizzes.any((quiz) => quiz.id == id);
    await db.delete('quiz_questions', where: 'quiz_id = ?', whereArgs: [id]);
    await db.delete('quizzes', where: 'id = ?', whereArgs: [id]);
    await db.delete('quiz_results', where: 'quiz_id = ?', whereArgs: [id]);
    _quizzes.removeWhere((quiz) => quiz.id == id);
    _history.removeWhere((result) => result.quizId == id);
    return removed;
  }

  @override
  Future<void> addResult(QuizResult result) async {
    await _ensureLoaded();
    final db = await _db;
    final id =
        'res-${DateTime.now().millisecondsSinceEpoch}-${result.quizId.hashCode}';
    await db.insert('quiz_results', {
      'id': id,
      'quiz_id': result.quizId,
      'quiz_title': result.quizTitle,
      'subject': result.subject,
      'difficulty': result.difficulty.name,
      'date_label': result.dateLabel,
      'correct_count': result.correctCount,
      'total_count': result.totalCount,
      'created_at': DateTime.now().toIso8601String(),
    });
    _history.insert(0, result);
  }

  Future<void> _insertQuiz(Database db, Quiz quiz) async {
    await db.insert(
      'quizzes',
      {
        'id': quiz.id,
        'title': quiz.title,
        'description': quiz.description,
        'subject': quiz.subject,
        'difficulty': quiz.difficulty.name,
        'estimated_minutes': quiz.estimatedMinutes,
        'generated_by_ai': quiz.generatedByAi ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    for (var i = 0; i < quiz.questions.length; i++) {
      final q = quiz.questions[i];
      await db.insert(
        'quiz_questions',
        {
          'id': q.id.isEmpty ? '${quiz.id}-q$i' : q.id,
          'quiz_id': quiz.id,
          'text': q.text,
          'options_json': jsonEncode(q.options),
          'correct_index': q.correctIndex,
          'explanation': q.explanation,
          'difficulty': q.difficulty.name,
          'sort_order': i,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Question _questionFromRow(Map<String, Object?> row) {
    final optionsRaw = row['options_json'] as String? ?? '[]';
    final options = (jsonDecode(optionsRaw) as List<dynamic>)
        .map((e) => e.toString())
        .toList();
    return Question(
      id: row['id'] as String,
      text: row['text'] as String,
      options: options,
      correctIndex: row['correct_index'] as int,
      explanation: row['explanation'] as String? ?? '',
      difficulty: quizDifficultyFromName(row['difficulty'] as String?),
    );
  }

  QuizResult _resultFromRow(Map<String, Object?> row) {
    return QuizResult(
      quizId: row['quiz_id'] as String,
      quizTitle: row['quiz_title'] as String,
      subject: row['subject'] as String,
      difficulty: quizDifficultyFromName(row['difficulty'] as String?),
      dateLabel: row['date_label'] as String,
      correctCount: row['correct_count'] as int,
      totalCount: row['total_count'] as int,
    );
  }
}
