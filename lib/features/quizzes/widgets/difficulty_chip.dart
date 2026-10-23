import 'package:flutter/material.dart';

import '../models/quiz.dart';
import '../theme/quiz_theme.dart';

class DifficultyChip extends StatelessWidget {
  const DifficultyChip({
    super.key,
    required this.difficulty,
    this.selected = false,
    this.onTap,
  });

  final QuizDifficulty difficulty;
  final bool selected;
  final VoidCallback? onTap;

  Color get _foreground {
    if (selected) return Colors.white;
    return switch (difficulty) {
      QuizDifficulty.facile => const Color(0xFF065F46),
      QuizDifficulty.moyen => const Color(0xFF92400E),
      QuizDifficulty.difficile => const Color(0xFF9F1239),
    };
  }

  Color get _background {
    if (selected) {
      return switch (difficulty) {
        QuizDifficulty.facile => QuizTokens.success,
        QuizDifficulty.moyen => QuizTokens.accent,
        QuizDifficulty.difficile => QuizTokens.danger,
      };
    }
    return switch (difficulty) {
      QuizDifficulty.facile => const Color(0xFFD1FAE5),
      QuizDifficulty.moyen => const Color(0xFFFEF3C7),
      QuizDifficulty.difficile => const Color(0xFFFFE4E6),
    };
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedContainer(
      duration: QuizTokens.anim,
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(QuizTokens.rBadge),
      ),
      child: Text(
        difficulty.label,
        style: QuizTokens.body(12, color: _foreground, weight: FontWeight.w600),
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(QuizTokens.rBadge),
        child: child,
      ),
    );
  }
}

class FilterChipButton extends StatelessWidget {
  const FilterChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: QuizTokens.anim,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? QuizTokens.primary : Colors.white,
          borderRadius: BorderRadius.circular(QuizTokens.rButton),
          boxShadow: selected ? QuizTokens.shadow : null,
        ),
        child: Text(
          label,
          style: QuizTokens.body(
            14,
            color: selected ? Colors.white : QuizTokens.text,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
