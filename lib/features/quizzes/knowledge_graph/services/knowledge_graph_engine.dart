import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/quiz.dart';
import '../../models/quiz_attempt.dart';
import '../../services/gemini_service.dart';
import '../../services/openrouter_service.dart';
import '../../services/quiz_ai_provider.dart';
import '../data/knowledge_graph_repository.dart';
import '../models/knowledge_concept.dart';
import '../models/knowledge_dashboard_stats.dart';
import '../models/knowledge_edge.dart';
import '../models/knowledge_enrichment_report.dart';
import '../models/knowledge_recommendation.dart';
import '../models/mastery_level.dart';
import '../models/question_concept_link.dart';
import '../models/student_concept_mastery.dart';
import 'concept_extraction_service.dart';
import 'concept_normalizer.dart';
import 'decision_engine.dart';
import 'knowledge_ai_client.dart';
import 'mastery_calculator.dart';

/// Orchestrateur : extraction (cache) → graphe → maîtrise → recommandations.
class KnowledgeGraphEngine {
  KnowledgeGraphEngine({
    KnowledgeGraphRepository? repository,
    ConceptExtractionService? extraction,
    KnowledgeAiClient? aiClient,
    MasteryCalculator masteryCalculator = const MasteryCalculator(),
    DecisionEngine decisionEngine = const DecisionEngine(),
    ConceptNormalizer normalizer = const ConceptNormalizer(),
  })  : _repo = repository ?? KnowledgeGraphRepository(),
        _extraction = extraction ?? ConceptExtractionService(),
        _ai = aiClient ?? KnowledgeAiClient(),
        _mastery = masteryCalculator,
        _decision = decisionEngine,
        _normalizer = normalizer;

  final KnowledgeGraphRepository _repo;
  final ConceptExtractionService _extraction;
  final KnowledgeAiClient _ai;
  final MasteryCalculator _mastery;
  final DecisionEngine _decision;
  final ConceptNormalizer _normalizer;

  /// Compat QuizViewModel : signature inchangée, configs cloud **ignorées**.
  /// Knowledge Graph utilise uniquement le LLM local (GGUF).
  void applyAiConfigs({
    GeminiConfig? gemini,
    OpenRouterConfig? openRouter,
    AiProviderKind? preferred,
  }) {
    _ai.reconfigure(
      geminiConfig: gemini,
      openRouterConfig: openRouter,
      preferredProvider: preferred,
    );
  }

  /// Sonde le fichier GGUF avant un enrichissement.
  Future<void> refreshLocalLlm() => _ai.refreshAvailability();

  bool get isAiConfigured => _ai.isConfigured;

  /// Dernière cause d’échec LLM (sanitisée).
  String? get lastAiFailureSummary => _ai.lastFailureSummary;

  /// Met à jour le graphe après une tentative (évolutif, pas une carte jetable).
  Future<void> afterAttempt({
    required Quiz quiz,
    required QuizAttempt attempt,
    required List<QuizAttempt> allUserAttempts,
    required List<Quiz> allQuizzes,
    bool allowNetwork = true,
  }) async {
    await ensureConceptsForQuiz(quiz, allowNetwork: allowNetwork);
    await recomputeMasteryForUser(
      userId: attempt.userId,
      attempts: allUserAttempts,
      quizzes: allQuizzes,
    );
  }

  Future<ConceptExtractionResult> ensureConceptsForQuiz(
    Quiz quiz, {
    bool allowNetwork = true,
    bool upgradeHeuristicCache = false,
  }) async {
    final detailed = await ensureConceptsForQuizDetailed(
      quiz,
      allowNetwork: allowNetwork,
      upgradeHeuristicCache: upgradeHeuristicCache,
    );
    return detailed.result;
  }

  /// Extraction avec chemin explicite (cache / IA / fallback) pour le feedback UI.
  Future<({ConceptExtractionResult result, KnowledgeExtractionPath path})>
      ensureConceptsForQuizDetailed(
    Quiz quiz, {
    bool allowNetwork = true,
    bool upgradeHeuristicCache = false,
  }) async {
    final quizId =
        quiz.id.isEmpty ? 'unsaved-${quiz.title.hashCode}' : quiz.id;

    if (quiz.questions.isEmpty) {
      debugPrint('KG engine: [skip] quiz=$quizId sans questions');
      return (
        result: const ConceptExtractionResult(
          concepts: [],
          relations: [],
          source: 'skipped',
        ),
        path: KnowledgeExtractionPath.skippedEmpty,
      );
    }

    final hash = _normalizer.contentHash(
      quizId: quizId,
      questions: [
        for (final q in quiz.questions)
          (id: q.id, text: q.text, explanation: q.explanation),
      ],
    );

    final cached = await _repo.getExtractionCache(quizId);
    final cacheHash = cached?['content_hash']?.toString();
    final cacheSource = cached?['source']?.toString() ?? '';
    final hashMatch = cached != null && cacheHash == hash;

    // Sonde le GGUF avant la décision cache/upgrade (sinon isConfigured=false).
    if (allowNetwork) {
      await _ai.refreshAvailability();
    }

    if (hashMatch) {
      // Retraite les caches heuristiques (ex. quiz-java/rest) quand ✨
      // demande un upgrade — les caches source=ai restent inchangés.
      final shouldUpgrade = allowNetwork &&
          _ai.isConfigured &&
          upgradeHeuristicCache &&
          cacheSource != 'ai';
      if (!shouldUpgrade) {
        final payload = cached['payload_json']?.toString() ?? '';
        try {
          final parsed = _extraction.parseAiPayload(payload, quiz);
          final result = ConceptExtractionResult(
            concepts: parsed.concepts,
            relations: parsed.relations,
            source: cacheSource.isEmpty ? 'cache' : cacheSource,
          );
          await _persistExtraction(quiz, quizId, result);
          return (
            result: result,
            path: cacheSource == 'ai'
                ? KnowledgeExtractionPath.cacheAi
                : KnowledgeExtractionPath.cacheHeuristic,
          );
        } catch (_) {
          // cache corrompu → recalcul ci-dessous
        }
      } else {
        debugPrint(
          'KG engine: [cache] quiz=$quizId source=$cacheSource '
          '→ retraitement LLM (upgrade heuristique)',
        );
      }
    }

    if (allowNetwork && _ai.isConfigured) {
      try {
        final result = await _extractWithOptionalCorrectiveRetry(quiz, quizId);
        final cacheJson = _extraction.encodeResultPayload(result);
        await _repo.saveExtractionCache(
          quizId: quizId,
          contentHash: hash,
          payloadJson: cacheJson,
          source: 'ai',
        );
        await _persistExtraction(quiz, quizId, result);
        debugPrint(
          'KG engine: [save] quiz=$quizId OK '
          'concepts=${result.concepts.length} '
          'relations=${result.relations.length} path=localLlm',
        );
        return (result: result, path: KnowledgeExtractionPath.localLlm);
      } catch (e) {
        // Remonte la cause parse/infer vers l’UI même si complete() a réussi.
        _ai.lastFailureSummary ??= e.toString();
        final reason = _ai.lastFailureSummary ?? e.toString();
        debugPrint(
          'KG engine: [fallback] quiz=$quizId heuristique (pas LLM) — $reason',
        );
        final result = _extraction.extractHeuristic(quiz);
        await _repo.saveExtractionCache(
          quizId: quizId,
          contentHash: hash,
          payloadJson: jsonEncode(_heuristicPayload(result)),
          source: 'heuristic',
        );
        await _persistExtraction(quiz, quizId, result);
        return (
          result: result,
          path: KnowledgeExtractionPath.fallbackHeuristic,
        );
      }
    }

    final result = _extraction.extractHeuristic(quiz);
    await _repo.saveExtractionCache(
      quizId: quizId,
      contentHash: hash,
      payloadJson: jsonEncode(_heuristicPayload(result)),
      source: 'heuristic',
    );
    await _persistExtraction(quiz, quizId, result);
    return (result: result, path: KnowledgeExtractionPath.localHeuristic);
  }

  /// 1) prompt normal → parse ; 2) si échec, **une** gen corrective courte.
  /// Ne fabrique aucun concept : le parse rejette toujours les IDs.
  Future<ConceptExtractionResult> _extractWithOptionalCorrectiveRetry(
    Quiz quiz,
    String quizId,
  ) async {
    final prompt = _extraction.buildExtractionPrompt(quiz);
    debugPrint(
      'KG engine: [load/gen] quiz=$quizId attempt=1 '
      'promptChars=${prompt.length}',
    );
    try {
      final raw = await _ai.complete(prompt);
      debugPrint(
        'KG engine: [parse] quiz=$quizId attempt=1 rawChars=${raw.length}',
      );
      return _extraction.parseAiPayload(raw, quiz);
    } catch (firstError) {
      debugPrint(
        'KG engine: [retry] quiz=$quizId corrective après : $firstError',
      );
      final corrective = _extraction.buildCorrectivePrompt(quiz);
      debugPrint(
        'KG engine: [load/gen] quiz=$quizId attempt=2 '
        'promptChars=${corrective.length}',
      );
      final raw2 = await _ai.complete(corrective);
      debugPrint(
        'KG engine: [parse] quiz=$quizId attempt=2 rawChars=${raw2.length}',
      );
      return _extraction.parseAiPayload(raw2, quiz);
    }
  }

  Map<String, dynamic> _heuristicPayload(ConceptExtractionResult result) => {
        'concepts': [
          for (final c in result.concepts)
            {
              'name': c.name,
              'description': c.description,
              'questionIds': c.questionIds,
              'skills': c.skills,
            },
        ],
        'relations': [
          for (final r in result.relations)
            {
              'from': r.from,
              'to': r.to,
              'type': r.type,
              'justification': r.justification,
            },
        ],
      };

  Future<void> _persistExtraction(
    Quiz quiz,
    String quizId,
    ConceptExtractionResult result,
  ) async {
    final idByCanon = <String, String>{};

    for (final draft in result.concepts) {
      final canon = _normalizer.canonicalize(draft.name);
      if (canon.isEmpty) continue;
      final existing = await _repo.findByCanonical(canon);
      final id = existing?.id ?? _normalizer.conceptIdFromCanonical(canon);
      idByCanon[canon] = id;
      await _repo.upsertConcept(
        KnowledgeConcept(
          id: id,
          canonicalName: canon,
          displayName: existing?.displayName ?? _normalizer.displayName(draft.name),
          subject: quiz.subject,
          description: draft.description.isNotEmpty
              ? draft.description
              : (existing?.description ?? ''),
          createdAt: existing?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      for (final qId in draft.questionIds) {
        await _repo.upsertQuestionConcept(
          QuestionConceptLink(
            id: 'qc-$qId-$id',
            questionId: qId,
            quizId: quizId,
            conceptId: id,
            skillLabel: draft.skills.isNotEmpty ? draft.skills.first : '',
          ),
        );
      }
    }

    for (final rel in result.relations) {
      final fromId = idByCanon[_normalizer.canonicalize(rel.from)];
      final toId = idByCanon[_normalizer.canonicalize(rel.to)];
      if (fromId == null || toId == null || fromId == toId) continue;
      final edgeId = 'e-$fromId-$toId-${rel.type}';
      await _repo.upsertEdge(
        KnowledgeEdge(
          id: edgeId,
          fromConceptId: fromId,
          toConceptId: toId,
          relationType: rel.type,
          justification: rel.justification,
        ),
      );
    }
  }

  Future<List<StudentConceptMastery>> recomputeMasteryForUser({
    required String userId,
    required List<QuizAttempt> attempts,
    required List<Quiz> quizzes,
  }) async {
    final links = await _repo.allLinks();
    final quizById = {for (final q in quizzes) q.id: q};
    // Inclure aussi les quiz des tentatives non listés
    final evidenceByConcept = <String, List<ConceptEvidence>>{};

    for (final attempt in attempts.where((a) => a.userId == userId)) {
      final quiz = quizById[attempt.quizId];
      final attemptLinks = links.where((l) => l.quizId == attempt.quizId);
      for (final link in attemptLinks) {
        var correct = false;
        var difficulty = attempt.difficulty;
        if (quiz != null) {
          final qi = quiz.questions.indexWhere((q) => q.id == link.questionId);
          if (qi >= 0 && qi < attempt.selectedAnswers.length) {
            correct =
                attempt.selectedAnswers[qi] == quiz.questions[qi].correctIndex;
            difficulty = quiz.questions[qi].difficulty;
          } else {
            continue;
          }
        } else {
          // Pas de quiz en mémoire : on ne peut pas juger question par question.
          continue;
        }
        evidenceByConcept.putIfAbsent(link.conceptId, () => []).add(
              ConceptEvidence(
                questionId: link.questionId,
                correct: correct,
                difficulty: difficulty,
                completedAt: attempt.completedAt,
                linkWeight: link.weight,
              ),
            );
      }
    }

    final concepts = await _repo.listConcepts();
    final results = <StudentConceptMastery>[];
    for (final c in concepts) {
      final evidence = evidenceByConcept[c.id] ?? const <ConceptEvidence>[];
      final mastery = _mastery.compute(
        userId: userId,
        conceptId: c.id,
        evidence: evidence,
      );
      await _repo.upsertMastery(mastery);
      results.add(mastery);
    }
    return results;
  }

  Future<KnowledgeDashboardStats> dashboardStats(String userId) async {
    final concepts = await _repo.listConcepts();
    final masteries = await _repo.masteryForUser(userId);
    if (concepts.isEmpty) return KnowledgeDashboardStats.empty;

    final byConcept = {for (final m in masteries) m.conceptId: m};
    var mastered = 0;
    var toImprove = 0;
    var uneval = 0;
    var sum = 0.0;
    var counted = 0;
    DateTime? last;

    for (final c in concepts) {
      final m = byConcept[c.id];
      if (m == null || m.level == MasteryLevel.unevalue) {
        uneval++;
        continue;
      }
      counted++;
      sum += m.scorePercent;
      if (m.level == MasteryLevel.bonne || m.level == MasteryLevel.excellente) {
        mastered++;
      } else {
        toImprove++;
      }
      if (m.updatedAt != null &&
          (last == null || m.updatedAt!.isAfter(last))) {
        last = m.updatedAt;
      }
    }

    return KnowledgeDashboardStats(
      globalMasteryPercent: counted == 0 ? 0 : sum / counted,
      conceptCount: concepts.length,
      masteredCount: mastered,
      toImproveCount: toImprove,
      unevaluatedCount: uneval,
      lastUpdated: last,
    );
  }

  Future<List<KnowledgeRecommendation>> recommendations({
    required String userId,
    required List<Quiz> quizzes,
  }) async {
    final concepts = await _repo.listConcepts();
    final edges = await _repo.listEdges();
    final masteries = await _repo.masteryForUser(userId);
    final links = await _repo.allLinks();
    return _decision.buildRecommendations(
      concepts: concepts,
      edges: edges,
      masteries: masteries,
      links: links,
      quizzes: quizzes,
    );
  }

  Future<List<KnowledgeConcept>> concepts() => _repo.listConcepts();
  Future<List<KnowledgeEdge>> edges() => _repo.listEdges();
  Future<List<StudentConceptMastery>> mastery(String userId) =>
      _repo.masteryForUser(userId);
  Future<List<QuestionConceptLink>> links() => _repo.allLinks();

  void dispose() {
    // ignore: discarded_futures
    _ai.dispose();
  }
}
