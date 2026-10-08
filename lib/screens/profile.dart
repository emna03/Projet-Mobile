import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const scores = [('Spring Boot', .82), ('Docker', .64), ('Microservices', .71), ('REST', .90)];

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        children: [
          Center(child: Column(children: [
            CircleAvatar(radius: 44, backgroundColor: SM.primary,
                child: Text('NJ', style: SM.h(26).copyWith(color: Colors.white))),
            const SizedBox(height: 12),
            Text('Nacef Jouini', style: SM.h(22)),
            Text('Licence 3 · Génie logiciel', style: SM.b(14, color: SM.muted)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(SM.rBadge)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.award, size: 16, color: Color(0xFF065F46)),
                const SizedBox(width: 6),
                Text('Étudiant actif', style: SM.b(13, color: const Color(0xFF065F46), w: FontWeight.w600)),
              ]),
            ),
          ])),
          const SizedBox(height: 24),
          const Row(children: [
            _Mini('24', 'Jours de suite'),
            SizedBox(width: 10),
            _Mini('8', 'Quiz réussis'),
            SizedBox(width: 10),
            _Mini('14 h', 'Révisées'),
          ]),
          const SizedBox(height: 20),
          SMCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Score par matière', style: SM.h(17)),
              const SizedBox(height: 16),
              for (final (name, v) in scores) ...[
                Row(children: [
                  Expanded(child: Text(name, style: SM.b(14, w: FontWeight.w600))),
                  Text('${(v * 100).round()}%', style: SM.b(14, color: SM.muted)),
                ]),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: v),
                  duration: const Duration(milliseconds: 600),
                  builder: (_, val, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: val, minHeight: 10,
                        color: v >= .8 ? SM.success : SM.primary, backgroundColor: SM.primarySoft),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ]),
          ),
        ],
      );
}

class _Mini extends StatelessWidget {
  final String v, l;
  const _Mini(this.v, this.l);
  @override
  Widget build(BuildContext context) => Expanded(
        child: SMCard(padding: const EdgeInsets.all(14), child: Column(children: [
          Text(v, style: SM.h(20)),
          Text(l, textAlign: TextAlign.center, style: SM.b(12, color: SM.muted)),
        ])),
      );
}
