import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/knowledge_recommendation.dart';
import '../models/mastery_level.dart';
import '../widgets/knowledge_graph_painter.dart';
import 'knowledge_map_shell.dart';

class KnowledgeRecommendationsPage extends StatelessWidget {
  const KnowledgeRecommendationsPage({
    super.key,
    required this.onOpenConcept,
  });

  final void Function(String conceptId) onOpenConcept;

  @override
  Widget build(BuildContext context) {
    final kg = KnowledgeScope.of(context);
    final recs = kg.recommendations;

    if (recs.isEmpty) {
      return const _RecoEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      itemCount: recs.length + 1,
      separatorBuilder: (_, index) =>
          SizedBox(height: index == 0 ? 16 : 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _RecoHeader(count: recs.length);
        }
        final r = recs[index - 1];
        return _RecoCard(
          recommendation: r,
          onTap: () => onOpenConcept(r.conceptId),
        );
      },
    );
  }
}

class _RecoHeader extends StatelessWidget {
  const _RecoHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Priorités de révision', style: SM.h(22)),
        const SizedBox(height: 6),
        Text(
          'Concepts à consolider en premier, classés selon vos résultats.',
          style: SM.b(14, color: SM.muted),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: SM.aiSoft,
            borderRadius: BorderRadius.circular(SM.rBadge),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.listOrdered, size: 16, color: SM.ai),
              const SizedBox(width: 8),
              Text(
                count == 1
                    ? '1 priorité identifiée'
                    : '$count priorités identifiées',
                style: SM.b(13, color: SM.ai, w: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecoEmptyState extends StatelessWidget {
  const _RecoEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 120),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: SM.aiSoft,
                shape: BoxShape.circle,
                boxShadow: SM.shadow,
              ),
              child: const Icon(LucideIcons.lightbulb, size: 32, color: SM.ai),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucune priorité pour le moment',
              textAlign: TextAlign.center,
              style: SM.h(18),
            ),
            const SizedBox(height: 10),
            Text(
              'Complétez quelques quiz : StudyMate analysera vos résultats '
              'et proposera ici un plan de révision clair.',
              textAlign: TextAlign.center,
              style: SM.b(14, color: SM.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoCard extends StatelessWidget {
  const _RecoCard({
    required this.recommendation,
    required this.onTap,
  });

  final KnowledgeRecommendation recommendation;
  final VoidCallback onTap;

  Color get _priorityAccent {
    final p = recommendation.priority;
    if (p <= 1) return SM.danger;
    if (p <= 3) return SM.accent;
    return SM.primary;
  }

  String get _priorityLabel {
    final p = recommendation.priority;
    if (p <= 1) return 'Urgent';
    if (p <= 3) return 'Important';
    return 'À planifier';
  }

  @override
  Widget build(BuildContext context) {
    final r = recommendation;
    final accent = _priorityAccent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SM.rCard),
        child: Ink(
          decoration: BoxDecoration(
            color: SM.card,
            borderRadius: BorderRadius.circular(SM.rCard),
            boxShadow: SM.shadow,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(SM.rCard),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PriorityBadge(
                              priority: r.priority,
                              label: _priorityLabel,
                              color: accent,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                r.conceptName,
                                style: SM.h(17),
                              ),
                            ),
                            Icon(
                              LucideIcons.chevronRight,
                              size: 20,
                              color: SM.muted.withValues(alpha: 0.65),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _ReasonBlock(reason: r.reason),
                        const SizedBox(height: 12),
                        _MasteryProgress(
                          current: r.currentLevel,
                          target: r.targetLevel,
                        ),
                        if (r.dependentOn.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _MetaRow(
                            icon: LucideIcons.gitBranch,
                            color: SM.accent,
                            title: 'Prérequis à revoir',
                            body: r.dependentOn.join(' · '),
                          ),
                        ],
                        if (r.relatedQuizIds.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _MetaRow(
                            icon: LucideIcons.bookOpen,
                            color: SM.primary,
                            title: 'Quiz associés',
                            body: r.relatedQuizIds.take(3).join(' · '),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({
    required this.priority,
    required this.label,
    required this.color,
  });

  final int priority;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SM.rBadge),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'P$priority',
            style: SM.b(13, color: color, w: FontWeight.w700),
          ),
          Text(
            label,
            style: SM.b(10, color: color, w: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ReasonBlock extends StatelessWidget {
  const _ReasonBlock({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SM.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.messageCircle, size: 16, color: SM.ai),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reason,
              style: SM.b(13, color: SM.text, w: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _MasteryProgress extends StatelessWidget {
  const _MasteryProgress({
    required this.current,
    required this.target,
  });

  final MasteryLevel current;
  final MasteryLevel target;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MasteryPill(
            label: current.label,
            color: masteryColor(current),
            caption: 'Actuel',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            LucideIcons.arrowRight,
            size: 16,
            color: SM.muted.withValues(alpha: 0.7),
          ),
        ),
        Expanded(
          child: _MasteryPill(
            label: target.label,
            color: SM.success,
            caption: 'Objectif',
          ),
        ),
      ],
    );
  }
}

class _MasteryPill extends StatelessWidget {
  const _MasteryPill({
    required this.label,
    required this.color,
    required this.caption,
  });

  final String label;
  final Color color;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption, style: SM.b(10, color: SM.muted, w: FontWeight.w600)),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: SM.b(12, color: color, w: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SM.b(11, color: color, w: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(body, style: SM.b(12, color: SM.muted)),
            ],
          ),
        ),
      ],
    );
  }
}
