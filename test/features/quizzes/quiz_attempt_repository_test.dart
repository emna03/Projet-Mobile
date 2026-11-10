import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studymate/features/quizzes/data/quiz_attempt_repository.dart';
import 'package:studymate/features/quizzes/models/quiz.dart';
import 'package:studymate/features/quizzes/models/quiz_attempt.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('persistance tentatives isolées par utilisateur + progression', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE quiz_attempts (
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
        },
      ),
    );

    final repo = QuizAttemptRepository(database: db);

    await repo.save(
      QuizAttempt(
        id: '1',
        userId: 'user-a',
        quizId: 'quiz-1',
        quizTitle: 'Java',
        subject: 'Java',
        difficulty: QuizDifficulty.facile,
        correctCount: 4,
        totalCount: 10,
        selectedAnswers: const [0, 1, 0, 0],
        completedAt: DateTime(2026, 1, 1),
      ),
    );
    await repo.save(
      QuizAttempt(
        id: '2',
        userId: 'user-a',
        quizId: 'quiz-1',
        quizTitle: 'Java',
        subject: 'Java',
        difficulty: QuizDifficulty.facile,
        correctCount: 7,
        totalCount: 10,
        selectedAnswers: const [0, 1, 0, 0],
        completedAt: DateTime(2026, 1, 2),
      ),
    );
    await repo.save(
      QuizAttempt(
        id: '3',
        userId: 'user-b',
        quizId: 'quiz-1',
        quizTitle: 'Java',
        subject: 'Java',
        difficulty: QuizDifficulty.facile,
        correctCount: 10,
        totalCount: 10,
        selectedAnswers: const [],
        completedAt: DateTime(2026, 1, 3),
      ),
    );

    final forA = await repo.listForUser('user-a');
    expect(forA, hasLength(2));
    expect(forA.every((e) => e.userId == 'user-a'), isTrue);

    final delta = repo.progressDeltaPercent(
      attemptsForQuiz: await repo.listForQuiz(userId: 'user-a', quizId: 'quiz-1'),
    );
    expect(delta, 30);

    await db.close();
  });
}
