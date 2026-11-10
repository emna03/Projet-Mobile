import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../viewmodels/quiz_viewmodel.dart';
import '../services/knowledge_graph_engine.dart';
import '../viewmodels/knowledge_graph_viewmodel.dart';
import 'concept_detail_page.dart';
import 'knowledge_dashboard_page.dart';
import 'knowledge_graph_canvas_page.dart';
import 'knowledge_recommendations_page.dart';

/// Point d’entrée « My Knowledge Map » depuis le module Quiz.
class KnowledgeMapShell extends StatefulWidget {
  const KnowledgeMapShell({super.key});

  @override
  State<KnowledgeMapShell> createState() => _KnowledgeMapShellState();
}

class _KnowledgeMapShellState extends State<KnowledgeMapShell> {
  KnowledgeGraphViewModel? _kg;
  int _tab = 0;

  KnowledgeGraphViewModel _ensureVm(QuizViewModel quizVm) {
    final existing = _kg;
    if (existing != null) {
      _syncAi(quizVm, existing);
      return existing;
    }
    final vm = KnowledgeGraphViewModel(
      userId: quizVm.currentUserId ?? 'local-demo',
      engine: KnowledgeGraphEngine(),
      quizzesProvider: () => quizVm.quizzes,
      attemptsProvider: () => quizVm.attempts,
    );
    _kg = vm;
    _syncAi(quizVm, vm);
    vm.load(allowNetwork: false);
    return vm;
  }

  void _syncAi(QuizViewModel quizVm, KnowledgeGraphViewModel kg) {
    kg.syncAiFromQuiz(
      gemini: quizVm.geminiRuntimeConfig,
      openRouter: quizVm.openRouterRuntimeConfig,
      preferred: quizVm.selectedAiProvider,
    );
  }

  Future<void> _onEnrichPressed(
    BuildContext context,
    KnowledgeGraphViewModel kg,
    QuizViewModel quizVm,
  ) async {
    _syncAi(quizVm, kg);
    final report = await kg.enrichWithAi();
    if (!context.mounted) return;
    // Vert = nouvelle gen LLM sans fallback ; ambre = mix/échec/indispo ;
    // primary = cache AI seul (pas un échec).
    final color = !report.aiConfigured
        ? SM.accent
        : report.isPositiveOutcome
            ? SM.success
            : (report.usedFallback || report.actionableQuizCount == 0)
                ? SM.accent
                : SM.primary;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Text(
          report.userMessage,
          style: SM.b(13, color: Colors.white),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _kg?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quizVm = QuizScope.of(context);
    final kg = _ensureVm(quizVm);

    return KnowledgeScope(
      notifier: kg,
      child: AnimatedBuilder(
        animation: kg,
        builder: (context, _) {
          return Scaffold(
            backgroundColor: SM.bg,
            appBar: AppBar(
              title: Text('My Knowledge Map', style: SM.h(18)),
              backgroundColor: SM.bg,
              actions: [
                IconButton(
                  tooltip: 'Actualiser (local / cache)',
                  onPressed:
                      kg.loading ? null : () => kg.load(allowNetwork: false),
                  icon: const Icon(LucideIcons.refreshCw),
                ),
                IconButton(
                  tooltip: 'Enrichir via LLM local (GGUF on-device)',
                  onPressed: kg.loading
                      ? null
                      : () => _onEnrichPressed(context, kg, quizVm),
                  icon: Icon(
                    LucideIcons.sparkles,
                    color: kg.loading ? SM.muted : SM.ai,
                  ),
                ),
              ],
              bottom: kg.loading
                  ? const PreferredSize(
                      preferredSize: Size.fromHeight(3),
                      child: LinearProgressIndicator(minHeight: 3),
                    )
                  : null,
            ),
            body: kg.loading && kg.concepts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      if (kg.loading && kg.concepts.isNotEmpty)
                        Material(
                          color: SM.ai.withValues(alpha: 0.08),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Enrichissement / actualisation en cours…',
                                    style: SM.b(12, color: SM.muted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: IndexedStack(
                          index: _tab,
                          children: [
                            KnowledgeDashboardPage(
                              onOpenGraph: () => setState(() => _tab = 1),
                            ),
                            KnowledgeGraphCanvasPage(
                              onOpenDetails: (id) {
                                kg.selectConcept(id);
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => KnowledgeScope(
                                      notifier: kg,
                                      child: ConceptDetailPage(conceptId: id),
                                    ),
                                  ),
                                );
                              },
                            ),
                            KnowledgeRecommendationsPage(
                              onOpenConcept: (id) {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => KnowledgeScope(
                                      notifier: kg,
                                      child: ConceptDetailPage(conceptId: id),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(LucideIcons.layoutDashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.share2),
                  label: 'Graphe',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.lightbulb),
                  label: 'Reco',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class KnowledgeScope extends InheritedNotifier<KnowledgeGraphViewModel> {
  const KnowledgeScope({
    super.key,
    required KnowledgeGraphViewModel notifier,
    required super.child,
  }) : super(notifier: notifier);

  static KnowledgeGraphViewModel of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<KnowledgeScope>();
    assert(scope != null, 'KnowledgeScope introuvable');
    return scope!.notifier!;
  }
}
