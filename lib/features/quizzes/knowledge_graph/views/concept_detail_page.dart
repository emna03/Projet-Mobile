import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sm_widgets.dart';
import '../models/mastery_level.dart';
import '../widgets/knowledge_graph_painter.dart';
import 'knowledge_map_shell.dart';

class ConceptDetailPage extends StatelessWidget {
  const ConceptDetailPage({super.key, required this.conceptId});

  final String conceptId;

  @override
  Widget build(BuildContext context) {
    final kg = KnowledgeScope.of(context);
    final concept = kg.conceptOf(conceptId);
    final mastery = kg.masteryOf(conceptId);
    final related = kg.edges
        .where(
          (e) => e.fromConceptId == conceptId || e.toConceptId == conceptId,
        )
        .toList();
    final recs =
        kg.recommendations.where((r) => r.conceptId == conceptId).toList();

    if (concept == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Concept')),
        body: const Center(child: Text('Concept introuvable')),
      );
    }

    final level = mastery?.level ?? MasteryLevel.unevalue;

    return Scaffold(
      backgroundColor: SM.bg,
      appBar: AppBar(
        title: Text(concept.displayName, style: SM.h(18)),
        backgroundColor: SM.bg,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          SMCard(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: masteryColor(level).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.hexagon, color: masteryColor(level)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(level.label, style: SM.h(18)),
                      Text(
                        mastery == null
                            ? 'Pas encore de preuves'
                            : '${mastery.scorePercent.toStringAsFixed(0)}% · '
                                '${mastery.distinctQuestions} question(s) · '
                                '${mastery.attemptCount} obs.',
                        style: SM.b(13, color: SM.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (concept.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(concept.description, style: SM.b(14)),
          ],
          const SizedBox(height: 16),
          Text('Preuves', style: SM.h(16)),
          const SizedBox(height: 8),
          SMCard(
            child: Column(
              children: [
                _row('Questions liées', '${kg.linkedQuestionCount(conceptId)}'),
                _row(
                  'Réussite pondérée',
                  mastery == null
                      ? '—'
                      : '${mastery.scorePercent.toStringAsFixed(1)}%',
                ),
                _row(
                  'Dernière activité',
                  mastery?.lastAttemptAt?.toIso8601String().substring(0, 16) ??
                      '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Concepts liés', style: SM.h(16)),
          const SizedBox(height: 8),
          if (related.isEmpty)
            Text('Aucune relation enregistrée.', style: SM.b(13, color: SM.muted))
          else
            ...related.map((e) {
              final otherId = e.fromConceptId == conceptId
                  ? e.toConceptId
                  : e.fromConceptId;
              final other = kg.conceptOf(otherId);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.gitBranch, color: SM.primary),
                title: Text(other?.displayName ?? otherId, style: SM.b(14)),
                subtitle: Text(
                  '${e.relationType}${e.justification.isEmpty ? '' : ' — ${e.justification}'}',
                  style: SM.b(12, color: SM.muted),
                ),
              );
            }),
          if (recs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Recommandation', style: SM.h(16)),
            const SizedBox(height: 8),
            SMCard(
              child: Text(recs.first.reason, style: SM.b(14)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(k, style: SM.b(13, color: SM.muted))),
            Text(v, style: SM.b(13, w: FontWeight.w600)),
          ],
        ),
      );
}
