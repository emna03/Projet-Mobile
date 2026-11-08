
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

class RegisterHeaderWidget extends StatefulWidget {
  const RegisterHeaderWidget({super.key});

  @override
  State<RegisterHeaderWidget> createState() =>
      _RegisterHeaderWidgetState();
}

class _RegisterHeaderWidgetState extends State<RegisterHeaderWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _floatingIcon({
    required double t,
    required IconData icon,
    required Alignment alignment,
    required double phase,
    double size = 22,
  }) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(0, math.sin(t + phase) * 7),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(SM.rBadge + 4),
          ),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SM.primary, SM.ai],
        ),
        borderRadius: BorderRadius.circular(SM.rCard + 4),
        boxShadow: SM.shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SM.rCard + 4),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value * 2 * math.pi;
            final pulse = 1 + 0.06 * math.sin(t * 2);

            return Stack(
              children: [
                Positioned(
                  top: -40,
                  right: -30,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  left: -30,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                _floatingIcon(
                  t: t,
                  icon: LucideIcons.bookOpen,
                  alignment: const Alignment(-0.82, -0.55),
                  phase: 0,
                ),
                _floatingIcon(
                  t: t,
                  icon: LucideIcons.lightbulb,
                  alignment: const Alignment(0.82, -0.6),
                  phase: 1.5,
                ),
                _floatingIcon(
                  t: t,
                  icon: LucideIcons.pencil,
                  alignment: const Alignment(-0.7, 0.7),
                  phase: 3,
                ),
                _floatingIcon(
                  t: t,
                  icon: LucideIcons.sparkles,
                  alignment: const Alignment(0.75, 0.65),
                  phase: 4.5,
                ),
                Center(
                  child: Transform.scale(
                    scale: pulse,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        LucideIcons.graduationCap,
                        color: SM.primary,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
