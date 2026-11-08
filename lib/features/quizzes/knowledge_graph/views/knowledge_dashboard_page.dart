import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sm_widgets.dart';
import 'knowledge_map_shell.dart';

class KnowledgeDashboardPage extends StatelessWidget {
  const KnowledgeDashboardPage({super.key, required this.onOpenGraph});

  final VoidCallback onOpenGraph;

  @override
  Widget build(BuildContext context) {
    final kg = KnowledgeScope.of(context);
    final s = kg.stats;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Text('Learning Intelligence', style: SM.h(22)),
        const SizedBox(height: 6),
        Text(
          'Carte de connaissances évolutive basée sur tes quiz réels.',
          style: SM.b(14, color: SM.muted),
        ),
        const SizedBox(height: 20),
        SMCard(
          color: SM.ai,
          child: Row(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: (s.globalMasteryPercent / 100).clamp(0, 1),
                      strokeWidth: 8,
                      backgroundColor: Colors.white24,
                      color: Colors.white,
                    ),
                    Center(
                      child: Text(
                        '${s.globalMasteryPercent.round()}%',
                        style: SM.h(18).copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maîtrise globale',
                      style: SM.b(13, color: Colors.white70, w: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Moyenne pondérée des concepts évalués',
                      style: SM.b(13, color: Colors.white),
                    ),
                    if (s.lastUpdated != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Maj ${_fmt(s.lastUpdated!)}',
                        style: SM.b(12, color: Colors.white60),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: LucideIcons.hexagon,
                value: '${s.conceptCount}',
                label: 'Concepts',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: LucideIcons.circleCheck,
                value: '${s.masteredCount}',
                label: 'Maîtrisés',
                color: SM.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: LucideIcons.triangleAlert,
                value: '${s.toImproveCount}',
                label: 'À améliorer',
                color: SM.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: LucideIcons.circleDashed,
                value: '${s.unevaluatedCount}',
                label: 'Non évalués',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onOpenGraph,
          style: FilledButton.styleFrom(
            backgroundColor: SM.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(LucideIcons.share2),
          label: const Text('Ouvrir le graphe interactif'),
        ),
        if (kg.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(kg.errorMessage!, style: SM.b(13, color: SM.danger)),
        ],
      ],
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.color = SM.primary,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SMCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(value, style: SM.h(22)),
          Text(label, style: SM.b(12, color: SM.muted)),
        ],
      ),
    );
  }
}
