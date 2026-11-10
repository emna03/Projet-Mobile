import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studymate/features/quizzes/data/quiz_local_database.dart';
import 'package:studymate/features/quizzes/knowledge_graph/data/knowledge_graph_repository.dart';
import 'package:studymate/features/quizzes/knowledge_graph/models/knowledge_concept.dart';
import 'package:studymate/features/quizzes/knowledge_graph/models/student_concept_mastery.dart';
import 'package:studymate/features/quizzes/knowledge_graph/models/mastery_level.dart';
import 'package:studymate/features/quizzes/knowledge_graph/services/concept_extraction_service.dart';
import 'package:studymate/features/quizzes/knowledge_graph/services/knowledge_graph_engine.dart';
import 'package:studymate/features/quizzes/models/question.dart';
import 'package:studymate/features/quizzes/models/quiz.dart';
import 'package:studymate/features/quizzes/models/quiz_attempt.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          // Réutilise les migrations via instance — on ouvre manuellement v3
          await db.execute('''
            CREATE TABLE kg_concepts (
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
            CREATE TABLE kg_edges (
              id TEXT PRIMARY KEY,
              from_concept_id TEXT NOT NULL,
              to_concept_id TEXT NOT NULL,
              relation_type TEXT NOT NULL,
              weight REAL NOT NULL DEFAULT 1.0,
              justification TEXT NOT NULL DEFAULT ''
            )
          ''');
          await db.execute('''
            CREATE TABLE kg_question_concepts (
              id TEXT PRIMARY KEY,
              question_id TEXT NOT NULL,
              quiz_id TEXT NOT NULL,
              concept_id TEXT NOT NULL,
              weight REAL NOT NULL DEFAULT 1.0,
              skill_label TEXT NOT NULL DEFAULT ''
            )
          ''');
          await db.execute('''
            CREATE TABLE kg_student_mastery (
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
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE kg_extraction_cache (
              quiz_id TEXT PRIMARY KEY,
              content_hash TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              source TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    QuizLocalDatabase.debugSetDatabase(db);
  });

  tearDown(() {
    QuizLocalDatabase.debugSetDatabase(null);
  });

  test('persistance concepts + isolation users', () async {
    final repo = KnowledgeGraphRepository();
    await repo.upsertConcept(
      KnowledgeConcept(
        id: 'c1',
        canonicalName: 'heritage',
        displayName: 'Héritage',
        subject: 'Java',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await repo.upsertMastery(
      StudentConceptMastery(
        id: 'm-u1-c1',
        userId: 'u1',
        conceptId: 'c1',
        scorePercent: 40,
        level: MasteryLevel.faible,
        correctWeight: 1,
        totalWeight: 2,
        attemptCount: 2,
        distinctQuestions: 2,
        updatedAt: DateTime.now(),
      ),
    );
    await repo.upsertMastery(
      StudentConceptMastery(
        id: 'm-u2-c1',
        userId: 'u2',
        conceptId: 'c1',
        scorePercent: 90,
        level: MasteryLevel.bonne,
        correctWeight: 3,
        totalWeight: 3,
        attemptCount: 3,
        distinctQuestions: 3,
        updatedAt: DateTime.now(),
      ),
    );

    final u1 = await repo.masteryForUser('u1');
    final u2 = await repo.masteryForUser('u2');
    expect(u1.single.scorePercent, 40);
    expect(u2.single.scorePercent, 90);
  });

  test('extraction heuristique + moteur sans réseau', () async {
    final quiz = Quiz(
      id: 'quiz-java',
      title: 'Java POO',
      description: 'Bases',
      subject: 'Java',
      difficulty: QuizDifficulty.moyen,
      estimatedMinutes: 10,
      questions: [
        const Question(
          id: 'q1',
          text: 'Qu’est-ce que l’héritage en Java ?',
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 1,
          explanation: 'Héritage et classes parentes',
        ),
        const Question(
          id: 'q2',
          text: 'Le polymorphisme permet quoi ?',
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 0,
          explanation: 'Polymorphisme dynamique',
        ),
      ],
    );

    final engine = KnowledgeGraphEngine();
    final extracted = await engine.ensureConceptsForQuiz(
      quiz,
      allowNetwork: false,
    );
    expect(extracted.concepts, isNotEmpty);
    expect(extracted.source, 'heuristic');

    final attempt = QuizAttempt(
      id: 'a1',
      userId: 'student-1',
      quizId: quiz.id,
      quizTitle: quiz.title,
      subject: quiz.subject,
      difficulty: quiz.difficulty,
      correctCount: 1,
      totalCount: 2,
      selectedAnswers: const [1, 1],
      completedAt: DateTime.now(),
    );

    await engine.afterAttempt(
      quiz: quiz,
      attempt: attempt,
      allUserAttempts: [attempt],
      allQuizzes: [quiz],
      allowNetwork: false,
    );

    final mastery = await engine.mastery('student-1');
    expect(mastery, isNotEmpty);
    engine.dispose();
  });

  test('fallback sans API conserve heuristique', () {
    final quiz = Quiz(
      id: 'q',
      title: 'Docker',
      description: '',
      subject: 'Docker',
      difficulty: QuizDifficulty.facile,
      estimatedMinutes: 5,
      questions: const [
        Question(
          id: '1',
          text: 'Dockerfile sert à construire une image',
          options: ['oui', 'non', 'parfois', 'jamais'],
          correctIndex: 0,
          explanation: 'Image Docker',
        ),
      ],
    );
    final r = ConceptExtractionService().extractHeuristic(quiz);
    expect(r.concepts.any((c) => c.name.toLowerCase().contains('docker')), isTrue);
  });
}
