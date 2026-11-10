import 'package:flutter/material.dart';

import '../../models/quiz.dart';
import '../../models/quiz_attempt.dart';
import '../../services/gemini_service.dart';
import '../../services/openrouter_service.dart';
import '../../services/quiz_ai_provider.dart';
import '../models/knowledge_concept.dart';
import '../models/knowledge_dashboard_stats.dart';
import '../models/knowledge_edge.dart';
import '../models/knowledge_enrichment_report.dart';
import '../models/knowledge_recommendation.dart';
import '../models/mastery_level.dart';
import '../models/question_concept_link.dart';
import '../models/student_concept_mastery.dart';
import '../services/concept_layout.dart';
import '../services/knowledge_graph_engine.dart';

class KnowledgeGraphViewModel extends ChangeNotifier {
  KnowledgeGraphViewModel({
    required this.userId,
    required KnowledgeGraphEngine engine,
    required List<Quiz> Function() quizzesProvider,
    required List<QuizAttempt> Function() attemptsProvider,
  })  : _engine = engine,
        _quizzesProvider = quizzesProvider,
        _attemptsProvider = attemptsProvider;

  final String userId;
  final KnowledgeGraphEngine _engine;
  final List<Quiz> Function() _quizzesProvider;
  final List<QuizAttempt> Function() _attemptsProvider;

  bool loading = false;
  String? errorMessage;
  KnowledgeDashboardStats stats = KnowledgeDashboardStats.empty;
  List<KnowledgeConcept> concepts = const [];
  List<KnowledgeEdge> edges = const [];
  List<StudentConceptMastery> masteries = const [];
  List<QuestionConceptLink> links = const [];
  List<KnowledgeRecommendation> recommendations = const [];
  String? selectedConceptId;
  List<GraphNodeLayout> layouts = const [];
  KnowledgeEnrichmentReport? lastEnrichment;

  bool get isAiConfigured => _engine.isAiConfigured;

  StudentConceptMastery? masteryOf(String conceptId) {
    for (final m in masteries) {
      if (m.conceptId == conceptId) return m;
    }
    return null;
  }

  KnowledgeConcept? conceptOf(String id) {
    for (final c in concepts) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Compat Quiz : configs cloud ignorées. Sonde le GGUF local.
  void syncAiFromQuiz({
    required GeminiConfig gemini,
    required OpenRouterConfig openRouter,
    required AiProviderKind preferred,
  }) {
    _engine.applyAiConfigs(
      gemini: gemini,
      openRouter: openRouter,
      preferred: preferred,
    );
    // ignore: discarded_futures
    _engine.refreshLocalLlm();
  }

  Future<void> load({
    bool allowNetwork = false,
    bool upgradeHeuristicCache = false,
  }) async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      for (final quiz in _quizzesProvider()) {
        if (quiz.id.isEmpty) continue;
        try {
          await _engine.ensureConceptsForQuiz(
            quiz,
            allowNetwork: allowNetwork,
            upgradeHeuristicCache: upgradeHeuristicCache,
          );
        } catch (_) {}
      }
      await _reloadDerivedState();
    } catch (e) {
      errorMessage = 'Knowledge Graph : $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Action du bouton ✨ — LLM local on-device (pas Gemini/OpenRouter).
  Future<KnowledgeEnrichmentReport> enrichWithAi() async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    var localLlm = 0;
    var cacheAi = 0;
    var cacheHeuristic = 0;
    var fallback = 0;
    var local = 0;
    var skippedEmpty = 0;
    var quizCount = 0;
    String? failureDetail;

    await _engine.refreshLocalLlm();
    final aiConfigured = _engine.isAiConfigured;

    try {
      if (!aiConfigured) {
        await _reloadDerivedState();
        final report = KnowledgeEnrichmentReport(
          aiConfigured: false,
          quizCount: _quizzesProvider().where((q) => q.id.isNotEmpty).length,
          localLlmCount: 0,
          cacheAiCount: 0,
          cacheHeuristicCount: 0,
          fallbackHeuristicCount: 0,
          localHeuristicCount: 0,
          skippedEmptyCount: 0,
          failureDetail: _engine.lastAiFailureSummary,
        );
        lastEnrichment = report;
        return report;
      }

      for (final quiz in _quizzesProvider()) {
        if (quiz.id.isEmpty) continue;
        quizCount++;
        try {
          final detailed = await _engine.ensureConceptsForQuizDetailed(
            quiz,
            allowNetwork: true,
            upgradeHeuristicCache: true,
          );
          switch (detailed.path) {
            case KnowledgeExtractionPath.localLlm:
              localLlm++;
            case KnowledgeExtractionPath.cacheAi:
              cacheAi++;
            case KnowledgeExtractionPath.cacheHeuristic:
              cacheHeuristic++;
            case KnowledgeExtractionPath.fallbackHeuristic:
              fallback++;
              failureDetail ??= _engine.lastAiFailureSummary;
            case KnowledgeExtractionPath.localHeuristic:
              local++;
            case KnowledgeExtractionPath.skippedEmpty:
              skippedEmpty++;
          }
        } catch (e) {
          fallback++;
          failureDetail ??=
              _engine.lastAiFailureSummary ?? e.toString();
        }
      }

      await _reloadDerivedState();

      final report = KnowledgeEnrichmentReport(
        aiConfigured: true,
        quizCount: quizCount,
        localLlmCount: localLlm,
        cacheAiCount: cacheAi,
        cacheHeuristicCount: cacheHeuristic,
        fallbackHeuristicCount: fallback,
        localHeuristicCount: local,
        skippedEmptyCount: skippedEmpty,
        failureDetail: failureDetail,
      );
      lastEnrichment = report;
      return report;
    } catch (e) {
      errorMessage = 'Knowledge Graph : $e';
      final report = KnowledgeEnrichmentReport(
        aiConfigured: aiConfigured,
        quizCount: quizCount,
        localLlmCount: localLlm,
        cacheAiCount: cacheAi,
        cacheHeuristicCount: cacheHeuristic,
        fallbackHeuristicCount: fallback + 1,
        localHeuristicCount: local,
        skippedEmptyCount: skippedEmpty,
        failureDetail:
            failureDetail ?? _engine.lastAiFailureSummary ?? e.toString(),
      );
      lastEnrichment = report;
      return report;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadDerivedState() async {
    await _engine.recomputeMasteryForUser(
      userId: userId,
      attempts: _attemptsProvider(),
      quizzes: _quizzesProvider(),
    );
    concepts = await _engine.concepts();
    edges = await _engine.edges();
    masteries = await _engine.mastery(userId);
    links = await _engine.links();
    stats = await _engine.dashboardStats(userId);
    recommendations = await _engine.recommendations(
      userId: userId,
      quizzes: _quizzesProvider(),
    );
    rebuildLayout(const Size(720, 720));
  }

  void rebuildLayout(Size size) {
    layouts = const ConceptLayoutEngine().layout(
      nodes: [
        for (final c in concepts)
          (
            id: c.id,
            label: c.displayName,
            level: masteryOf(c.id)?.level ?? MasteryLevel.unevalue,
            score: masteryOf(c.id)?.scorePercent ?? 0,
          ),
      ],
      edges: edges,
      canvasSize: size,
    );
  }

  void selectConcept(String? id) {
    selectedConceptId = id;
    notifyListeners();
  }

  Future<void> refreshAfterAttempt({
    required Quiz quiz,
    required QuizAttempt attempt,
    bool allowNetwork = true,
  }) async {
    await _engine.afterAttempt(
      quiz: quiz,
      attempt: attempt,
      allUserAttempts: _attemptsProvider(),
      allQuizzes: _quizzesProvider(),
      allowNetwork: allowNetwork,
    );
    await load(allowNetwork: false);
  }

  int linkedQuestionCount(String conceptId) =>
      links.where((l) => l.conceptId == conceptId).length;

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }
}
