import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sm_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          const PageTitle(
            'Bonjour Nacef',
            subtitle: 'Prêt pour une nouvelle séance ?',
          ),

          SMCard(
            color: SM.ai,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.sparkles,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recommandation IA',
                      style: SM.b(
                        13,
                        color: Colors.white70,
                        w: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Text(
                  'Révise Docker avant ta prochaine séance',
                  style: SM.h(18).copyWith(color: Colors.white),
                ),

                const SizedBox(height: 14),

                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  onPressed: () {
                    // Page quiz pas encore créée
                  },
                  child: const Text('Créer un quiz IA'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: const [
              _Stat(
                '12',
                'Ressources',
                LucideIcons.bookOpen,
              ),
              SizedBox(width: 10),
              _Stat(
                '8',
                'Quiz',
                LucideIcons.listChecks,
              ),
              SizedBox(width: 10),
              _Stat(
                '78%',
                'Score moyen',
                LucideIcons.trendingUp,
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            'Reprendre',
            style: SM.h(17),
          ),

          const SizedBox(height: 10),

          SMCard(
            child: Row(
              children: [
                const Icon(
                  LucideIcons.fileText,
                  color: SM.primary,
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Introduction à Docker',
                        style: SM.b(
                          15,
                          w: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const LinearProgressIndicator(
                          value: .6,
                          minHeight: 6,
                          color: SM.primary,
                          backgroundColor: SM.primarySoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Prochaine séance',
            style: SM.h(17),
          ),

          const SizedBox(height: 10),

          SMCard(
            child: Row(
              children: [
                const Icon(
                  LucideIcons.calendarClock,
                  color: SM.accent,
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    'Docker · 10/10/2026 à 14:00',
                    style: SM.b(
                      15,
                      w: FontWeight.w600,
                    ),
                  ),
                ),

                const SMBadge('En ligne'),
              ],
            ),
          ),
        ],
      );
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _Stat(
    this.value,
    this.label,
    this.icon,
  );

  @override
  Widget build(BuildContext context) => Expanded(
        child: SMCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: SM.primary,
                size: 20,
              ),

              const SizedBox(height: 8),

              Text(
                value,
                style: SM.h(20),
              ),

              Text(
                label,
                style: SM.b(
                  12,
                  color: SM.muted,
                ),
              ),
            ],
          ),
        ),
      );
}