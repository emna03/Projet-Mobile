import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/quizzes/knowledge_graph/models/knowledge_enrichment_report.dart';
import 'package:studymate/features/quizzes/knowledge_graph/services/concept_extraction_service.dart';
import 'package:studymate/features/quizzes/models/question.dart';
import 'package:studymate/features/quizzes/models/quiz.dart';

Quiz _quizWithTechIds() => Quiz(
      id: 'quiz-java',
      title: 'Quiz Java',
      description: '',
      subject: 'Java',
      difficulty: QuizDifficulty.moyen,
      estimatedMinutes: 10,
      questions: const [
        Question(
          id: 'java-0',
          text: 'Quel mot-clé sert à hériter ?',
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 0,
          explanation: '',
        ),
        Question(
          id: 'rest-0',
          text: 'Quel verbe HTTP crée une ressource ?',
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 0,
          explanation: '',
        ),
        Question(
          id: 'docker-1',
          text: 'Une image Docker contient ?',
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 1,
          explanation: '',
        ),
      ],
    );

void main() {
  final svc = ConceptExtractionService();

  group('filtre IDs techniques', () {
    test('rejette java-0, rest-0, docker-1', () {
      expect(
        ConceptExtractionService.isPlaceholderConceptName('java-0'),
        isTrue,
      );
      expect(
        ConceptExtractionService.isPlaceholderConceptName('rest-0'),
        isTrue,
      );
      expect(
        ConceptExtractionService.isPlaceholderConceptName('docker-1'),
        isTrue,
      );
    });

    test('accepte des notions pédagogiques réelles', () {
      expect(
        ConceptExtractionService.isPlaceholderConceptName('Héritage'),
        isFalse,
      );
      expect(
        ConceptExtractionService.isPlaceholderConceptName('Adresse IP'),
        isFalse,
      );
      expect(
        ConceptExtractionService.isPlaceholderConceptName('Conteneur Docker'),
        isFalse,
      );
    });

    test('parse refuse une réponse uniquement composée d’IDs', () {
      const raw =
          '{"concepts":[{"name":"java-0","questionIds":["java-0"]},'
          '{"name":"rest-0","questionIds":["rest-0"]},'
          '{"name":"docker-1","questionIds":["docker-1"]}],"relations":[]}';
      expect(
        () => svc.parseAiPayload(raw, _quizWithTechIds()),
        throwsA(
          isA<Object>().having(
            (e) => e.toString(),
            'msg',
            contains('aucun concept valide'),
          ),
        ),
      );
    });

    test('parse accepte un JSON avec notions réelles + ids techniques en questionIds',
        () {
      const raw =
          '{"concepts":[{"name":"Héritage","questionIds":["java-0"]},'
          '{"name":"API REST","questionIds":["rest-0"]}],'
          '"relations":[{"from":"Héritage","to":"API REST","type":"related"}]}';
      final r = svc.parseAiPayload(raw, _quizWithTechIds());
      expect(r.source, 'ai');
      expect(r.concepts.length, 2);
      expect(
        r.concepts.every(
          (c) => !ConceptExtractionService.isPlaceholderConceptName(c.name),
        ),
        isTrue,
      );
    });

    test('prompt interdit explicitement les IDs et fournit un exemple', () {
      final p = svc.buildExtractionPrompt(_quizWithTechIds());
      expect(p, contains('INTERDIT'));
      expect(p, contains('java-0'));
      expect(p, contains('Héritage'));
      expect(p, contains('Exemple JSON'));
      final c = svc.buildCorrectivePrompt(_quizWithTechIds());
      expect(c.toLowerCase(), contains('corrige'));
      expect(c, contains('java-0'));
    });
  });

  group('messages d’agrégation', () {
    test('succès LLM strict', () {
      const r = KnowledgeEnrichmentReport(
        aiConfigured: true,
        quizCount: 2,
        localLlmCount: 2,
        cacheAiCount: 0,
        cacheHeuristicCount: 0,
        fallbackHeuristicCount: 0,
        localHeuristicCount: 0,
      );
      expect(r.isAiSuccess, isTrue);
      expect(r.userMessage.toLowerCase(), contains('réussi'));
    });

    test('mix LLM + fallback → partiel', () {
      const r = KnowledgeEnrichmentReport(
        aiConfigured: true,
        quizCount: 3,
        localLlmCount: 1,
        cacheAiCount: 0,
        cacheHeuristicCount: 0,
        fallbackHeuristicCount: 2,
        localHeuristicCount: 0,
        failureDetail: 'aucun concept valide',
      );
      expect(r.isAiSuccess, isTrue);
      expect(r.userMessage.toLowerCase(), contains('partiel'));
      expect(r.userMessage.toLowerCase(), contains('heuristique'));
    });

    test('cache AI + fallback (sans nouvelle gen) → mixte, pas échec global', () {
      const r = KnowledgeEnrichmentReport(
        aiConfigured: true,
        quizCount: 5,
        localLlmCount: 0,
        cacheAiCount: 3,
        cacheHeuristicCount: 0,
        fallbackHeuristicCount: 2,
        localHeuristicCount: 0,
        failureDetail: 'Extraction IA : aucun concept valide.',
      );
      expect(r.isAiSuccess, isFalse);
      expect(r.userMessage.toLowerCase(), contains('mixte'));
      expect(r.userMessage.toLowerCase(), isNot(contains('llm local en échec')));
    });

    test('échec réel : aucun AI', () {
      const r = KnowledgeEnrichmentReport(
        aiConfigured: true,
        quizCount: 2,
        localLlmCount: 0,
        cacheAiCount: 0,
        cacheHeuristicCount: 0,
        fallbackHeuristicCount: 2,
        localHeuristicCount: 0,
        failureDetail: 'infer: timeout',
      );
      expect(r.userMessage.toLowerCase(), contains('échec'));
      expect(r.userMessage, contains('timeout'));
    });

    test('quiz vides uniquement → informatif', () {
      const r = KnowledgeEnrichmentReport(
        aiConfigured: true,
        quizCount: 2,
        localLlmCount: 0,
        cacheAiCount: 0,
        cacheHeuristicCount: 0,
        fallbackHeuristicCount: 0,
        localHeuristicCount: 0,
        skippedEmptyCount: 2,
      );
      expect(r.actionableQuizCount, 0);
      expect(r.userMessage.toLowerCase(), contains('exploitable'));
      expect(r.userMessage.toLowerCase(), contains('hors llm'));
      expect(r.userMessage.toLowerCase(), isNot(contains('llm local en échec')));
    });

    test('cache AI seul → déjà enrichi', () {
      const r = KnowledgeEnrichmentReport(
        aiConfigured: true,
        quizCount: 4,
        localLlmCount: 0,
        cacheAiCount: 4,
        cacheHeuristicCount: 0,
        fallbackHeuristicCount: 0,
        localHeuristicCount: 0,
      );
      expect(r.userMessage.toLowerCase(), contains('cache'));
      expect(r.userMessage.toLowerCase(), isNot(contains('échec')));
    });
  });
}
