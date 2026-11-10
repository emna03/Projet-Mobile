import 'package:flutter/material.dart';
import 'package:studymate/theme/app_colors.dart';

class StudyHeader extends StatelessWidget {
  const StudyHeader({
    super.key,
    required this.initials,
    this.onBellTap,
    this.hasAlerts = false,
  });

  final String initials;

  /// Appelé quand on touche la cloche des notifications.
  final VoidCallback? onBellTap;

  /// Affiche le point orange : au moins une séance à venir est rappelée.
  final bool hasAlerts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 10),
        const Text(
          'StudyMate.',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const Spacer(),
        _BellButton(onTap: onBellTap, showDot: hasAlerts),
        const SizedBox(width: 10),
        _Avatar(initials: initials),
      ],
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.onTap, required this.showDot});

  final VoidCallback? onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Notifications',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 0,
        shadowColor: const Color(0xFF5C4BFF).withValues(alpha: 0.08),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5C4BFF).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.text,
                  size: 22,
                ),
                if (showDot)
                  const Positioned(
                    top: 10,
                    right: 11,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.dot,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 8, height: 8),
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.avatar,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w800,
          fontSize: 14,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
