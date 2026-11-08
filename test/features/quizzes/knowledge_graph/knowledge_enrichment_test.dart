import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studymate/features/quizzes/data/quiz_local_database.dart';
import 'package:studymate/features/quizzes/knowledge_graph/models/knowledge_enrichment_report.dart';
import 'package:studymate/features/quizzes/knowledge_graph/services/knowledge_ai_client.dart';
import 'package:studymate/features/quizzes/knowledge_graph/services/knowledge_graph_engine.dart';
import 'package:studymate/features/quizzes/knowledge_graph/services/local_llm/local_model_manager.dart';
import 'package:studymate/features/quizzes/knowledge_graph/viewmodels/knowledge_graph_viewmodel.dart';
import 'package:studymate/features/quizzes/models/question.dart';
import 'package:studymate/features/quizzes/models/quiz.dart';
import 'package:studymate/features/quizzes/services/gemini_service.dart';
import 'package:studymate/features/quizzes/services/openrouter_service.dart';
import 'package:studymate/features/quizzes/services/quiz_ai_provider.dart';

Quiz _sampleQuiz() => Quiz(
      id: 'quiz-enrich-1',
      title: 'Java POO',
      description: 'Bases',
      subject: 'Java',
      difficulty: QuizDifficulty.moyen,
      estimatedMinutes: 10,
      questions: const [
        Question(
          id: 'q1',
          text: 'Qu’est-ce que l’héritage en Java ?',
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 1,
          explanation: 'Héritage',
        ),
        Question(
          id: 'q2',
          text: 'Le polymorphisme permet quoi ?',
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 0,
          explanation: 'Polymorphisme',
        ),
      ],
    );

String _aiExtractionJson() => jsonEncode({
      'concepts': [
        {
          'name': 'Héritage',
          'description': 'Relation is-a',
          'questionIds': ['q1'],
          'skills': ['POO'],
        },
        {
          'name': 'Polymorphisme',
          'description': 'Comportements multiples',
          'questionIds': ['q2'],
          'skills': ['POO'],
        },
      ],
      'relations': [
        {
          'from': 'Héritage',
          'to': 'Polymorphisme',
          'type': 'related',
          'justification': 'Concepts POO liés',
        },
      ],
    });

Future<Database> _openKgDb() async {
  final db = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 3,
      onCreate: (db, version) async {
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
  return db;
}

Future<void> _clearKgTables(Database db) async {
  await db.delete('kg_extraction_cache');
  await db.delete('kg_question_concepts');
  await db.delete('kg_edges');
  await db.delete('kg_student_mastery');
  await db.delete('kg_concepts');
}

void main() {
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await _openKgDb();
  });

  setUp(() async {
    QuizLocalDatabase.debugSetDatabase(db);
    await _clearKgTables(db);
  });

  tearDownAll(() {
    QuizLocalDatabase.debugSetDatabase(null);
  });

  test('LLM local absent → rapport clair, pas de faux succès', () async {
    final quiz = _sampleQuiz();
    final engine = KnowledgeGraphEngine(
      aiClient: KnowledgeAiClient(
        availabilityProbe: () async => false,
        testCompleter: (_) async => throw StateError('ne doit pas être appelé'),
      ),
    );
    await engine.refreshLocalLlm();
    final vm = KnowledgeGraphViewModel(
      userId: 'u1',
      engine: engine,
      quizzesProvider: () => [quiz],
      attemptsProvider: () => const [],
    );

    final report = await vm.enrichWithAi();
    expect(report.aiConfigured, isFalse);
    expect(report.isAiSuccess, isFalse);
    expect(report.userMessage.toLowerCase(), contains('llm local'));
    engine.dispose();
  });

  test('LLM local (test-double) → localLlm + concepts SQLite', () async {
    final quiz = _sampleQuiz();
    final engine = KnowledgeGraphEngine(
      aiClient: KnowledgeAiClient(
        availabilityProbe: () async => true,
        testCompleter: (_) async => _aiExtractionJson(),
      ),
    );

    final detailed = await engine.ensureConceptsForQuizDetailed(
      quiz,
      allowNetwork: true,
      upgradeHeuristicCache: true,
    );
    expect(detailed.path, KnowledgeExtractionPath.localLlm);
    expect(detailed.result.concepts, isNotEmpty);
    expect(detailed.result.source, 'ai');

    final vm = KnowledgeGraphViewModel(
      userId: 'u1',
      engine: engine,
      quizzesProvider: () => [quiz],
      attemptsProvider: () => const [],
    );
    final report = await vm.enrichWithAi();
    expect(report.aiConfigured, isTrue);
    expect(report.cacheAiCount, 1);
    expect(report.localLlmCount, 0);
    expect(report.userMessage.toLowerCase(), contains('cache'));
    engine.dispose();
  });

  test('échec LLM → fallback heuristique clairement non-LLM', () async {
    final quiz = _sampleQuiz();
    final engine = KnowledgeGraphEngine(
      aiClient: KnowledgeAiClient(
        availabilityProbe: () async => true,
        testCompleter: (_) async => throw StateError('OOM simulé'),
      ),
    );

    final detailed = await engine.ensureConceptsForQuizDetailed(
      quiz,
      allowNetwork: true,
      upgradeHeuristicCache: true,
    );
    expect(detailed.path, KnowledgeExtractionPath.fallbackHeuristic);
    expect(detailed.result.source, 'heuristic');
    expect(engine.lastAiFailureSummary, isNotNull);
    engine.dispose();
  });

  test('LocalModelManager détecte absence / taille invalide', () async {
    final dir = await Directory.systemTemp.createTemp('kg_llm_');
    addTearDown(() => dir.delete(recursive: true));
    final mgr = LocalModelManager(
      overrideDirectory: dir,
      overrideFileName: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
    );
    expect(await mgr.isModelAvailable(), isFalse);

    final tiny = File('${dir.path}/qwen2.5-0.5b-instruct-q4_k_m.gguf');
    await tiny.writeAsString('not-a-real-gguf');
    expect(await mgr.isModelAvailable(), isFalse);
    expect(mgr.lastStatusMessage, contains('taille'));
  });

  test('syncAiFromQuiz n’active pas Gemini cloud pour KG', () {
    final engine = KnowledgeGraphEngine(
      aiClient: KnowledgeAiClient(
        availabilityProbe: () async => false,
      ),
    );
    expect(engine.isAiConfigured, isFalse);

    final vm = KnowledgeGraphViewModel(
      userId: 'u1',
      engine: engine,
      quizzesProvider: () => const [],
      attemptsProvider: () => const [],
    );
    vm.syncAiFromQuiz(
      gemini: GeminiConfig(apiKey: 'should-be-ignored', proxyUrl: ''),
      openRouter: OpenRouterConfig(apiKey: 'ignored', proxyUrl: ''),
      preferred: AiProviderKind.gemini,
    );
    // Sans GGUF, toujours false — la clé cloud ne configure plus le KG.
    expect(engine.isAiConfigured, isFalse);
    engine.dispose();
  });

  test('messages rapport : succès LLM vs heuristique', () {
    const ok = KnowledgeEnrichmentReport(
      aiConfigured: true,
      quizCount: 2,
      localLlmCount: 2,
      cacheAiCount: 0,
      cacheHeuristicCount: 0,
      fallbackHeuristicCount: 0,
      localHeuristicCount: 0,
    );
    expect(ok.isAiSuccess, isTrue);
    expect(ok.userMessage.toLowerCase(), contains('llm local'));

    const fallback = KnowledgeEnrichmentReport(
      aiConfigured: true,
      quizCount: 1,
      localLlmCount: 0,
      cacheAiCount: 0,
      cacheHeuristicCount: 0,
      fallbackHeuristicCount: 1,
      localHeuristicCount: 0,
    );
    expect(fallback.isAiSuccess, isFalse);
    expect(fallback.userMessage.toLowerCase(), contains('heuristique'));
  });

  test('quiz vide → skippedEmpty (pas un échec LLM)', () async {
    final empty = Quiz(
      id: 'quiz-empty',
      title: 'Vide',
      description: '',
      subject: 'X',
      difficulty: QuizDifficulty.facile,
      estimatedMinutes: 1,
      questions: const [],
    );
    final engine = KnowledgeGraphEngine(
      aiClient: KnowledgeAiClient(
        availabilityProbe: () async => true,
        testCompleter: (_) async => throw StateError('ne doit pas être appelé'),
      ),
    );
    final detailed = await engine.ensureConceptsForQuizDetailed(
      empty,
      allowNetwork: true,
      upgradeHeuristicCache: true,
    );
    expect(detailed.path, KnowledgeExtractionPath.skippedEmpty);
    engine.dispose();
  });

  test('cache heuristique est retraité (upgrade) vers LLM', () async {
    final quiz = _sampleQuiz();
    // 1) seed cache heuristique
    final seed = KnowledgeGraphEngine(
      aiClient: KnowledgeAiClient(
        availabilityProbe: () async => false,
      ),
    );
    final first = await seed.ensureConceptsForQuizDetailed(
      quiz,
      allowNetwork: false,
    );
    expect(first.path, KnowledgeExtractionPath.localHeuristic);
    seed.dispose();

    var llmCalls = 0;
    final engine = KnowledgeGraphEngine(
      aiClient: KnowledgeAiClient(
        availabilityProbe: () async => true,
        testCompleter: (_) async {
          llmCalls++;
          return _aiExtractionJson();
        },
      ),
    );
    final upgraded = await engine.ensureConceptsForQuizDetailed(
      quiz,
      allowNetwork: true,
      upgradeHeuristicCache: true,
    );
    expect(upgraded.path, KnowledgeExtractionPath.localLlm);
    expect(llmCalls, 1);

    // Cache AI ne doit PAS être retraité.
    final again = await engine.ensureConceptsForQuizDetailed(
      quiz,
      allowNetwork: true,
      upgradeHeuristicCache: true,
    );
    expect(again.path, KnowledgeExtractionPath.cacheAi);
    expect(llmCalls, 1);
    engine.dispose();
  });

  test('retry correctif puis succès LLM (sans inventer)', () async {
    final quiz = _sampleQuiz();
    var calls = 0;
    final engine = KnowledgeGraphEngine(
      aiClient: KnowledgeAiClient(
        availabilityProbe: () async => true,
        testCompleter: (_) async {
          calls++;
          if (calls == 1) {
            return '{"concepts":[{"name":"java-0","questionIds":["q1"]}],'
                '"relations":[]}';
          }
          return _aiExtractionJson();
        },
      ),
    );
    final detailed = await engine.ensureConceptsForQuizDetailed(
      quiz,
      allowNetwork: true,
      upgradeHeuristicCache: true,
    );
    expect(detailed.path, KnowledgeExtractionPath.localLlm);
    expect(calls, 2);
    expect(detailed.result.source, 'ai');
    engine.dispose();
  });
}
