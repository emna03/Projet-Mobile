import 'package:flutter/material.dart';
import 'package:studymate/theme/app_colors.dart';

class StudyHeader extends StatelessWidget {
  const StudyHeader({super.key});

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
        const _BellButton(),
        const SizedBox(width: 10),
        const _Avatar(initials: 'AB'),
      ],
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5C4BFF).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, color: AppColors.text, size: 22),
          Positioned(
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
