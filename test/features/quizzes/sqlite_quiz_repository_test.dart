import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studymate/features/quizzes/data/quiz_local_database.dart';
import 'package:studymate/features/quizzes/data/quiz_repository.dart';
import 'package:studymate/features/quizzes/models/question.dart';
import 'package:studymate/features/quizzes/models/quiz.dart';
import 'package:studymate/features/quizzes/models/quiz_result.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    QuizLocalDatabase.debugSetDatabase(null);
  });

  test('persiste create / update / delete / history en SQLite', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          // Réutilise le schéma via une instance temporaire.
          await db.execute('''
            CREATE TABLE quizzes (
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
            CREATE TABLE quiz_questions (
              id TEXT PRIMARY KEY,
              quiz_id TEXT NOT NULL,
              text TEXT NOT NULL,
              options_json TEXT NOT NULL,
              correct_index INTEGER NOT NULL,
              explanation TEXT NOT NULL,
              difficulty TEXT NOT NULL,
              sort_order INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE quiz_results (
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
        },
      ),
    );

    final repo = SqliteQuizRepository(database: db);
    await repo.load();
    // Base vide → seed mockQuizzes
    expect(repo.getAll(), isNotEmpty);

    final created = await repo.create(
      Quiz(
        id: '',
        title: 'Persistant',
        description: 'D',
        subject: 'Dart',
        difficulty: QuizDifficulty.moyen,
        estimatedMinutes: 8,
        questions: const [
          Question(
            id: 'q1',
            text: '2+2 ?',
            options: ['3', '4', '5', '6'],
            correctIndex: 1,
            explanation: '4',
          ),
        ],
      ),
    );
    expect(created.id, isNotEmpty);
    expect(repo.getById(created.id)?.title, 'Persistant');

    await repo.update(created.copyWith(title: 'Mis à jour'));
    expect(repo.getById(created.id)?.title, 'Mis à jour');

    await repo.addResult(
      QuizResult(
        quizId: created.id,
        quizTitle: 'Mis à jour',
        subject: 'Dart',
        difficulty: QuizDifficulty.moyen,
        dateLabel: '1 janv. 2026',
        correctCount: 1,
        totalCount: 1,
      ),
    );
    expect(repo.getHistory().first.quizTitle, 'Mis à jour');

    expect(await repo.delete(created.id), isTrue);
    expect(repo.getById(created.id), isNull);

    await db.close();
  });
}
