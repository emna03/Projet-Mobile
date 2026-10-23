import 'package:flutter/material.dart';

import '../theme/quiz_theme.dart';

enum AnswerVisualState { idle, selected, correct, incorrect }

class AnswerOption extends StatelessWidget {
  const AnswerOption({
    super.key,
    required this.index,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final int index;
  final String label;
  final AnswerVisualState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final letter = 'ABCD'[index];
    Color border = Colors.transparent;
    Color background = Colors.white;
    IconData? icon;
    Color iconColor = QuizTokens.primary;

    switch (state) {
      case AnswerVisualState.selected:
        border = QuizTokens.primary;
        background = QuizTokens.primarySoft;
      case AnswerVisualState.correct:
        border = QuizTokens.success;
        background = const Color(0xFFD1FAE5);
        icon = Icons.check;
        iconColor = QuizTokens.success;
      case AnswerVisualState.incorrect:
        border = QuizTokens.danger;
        background = const Color(0xFFFEE2E2);
        icon = Icons.close;
        iconColor = QuizTokens.danger;
      case AnswerVisualState.idle:
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: QuizTokens.anim,
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(QuizTokens.rButton),
          border: Border.all(color: border, width: 2),
          boxShadow: QuizTokens.shadow,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: QuizTokens.primarySoft,
              child: Text(
                letter,
                style: QuizTokens.body(13, color: QuizTokens.primary, weight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: QuizTokens.body(15))),
            if (icon != null) Icon(icon, color: iconColor),
          ],
        ),
      ),
    );
  }
}
