import 'package:flutter/material.dart';

import '../models/quiz.dart';
import '../theme/quiz_theme.dart';
import 'difficulty_chip.dart';

class QuizCard extends StatelessWidget {
  const QuizCard({super.key, required this.quiz, required this.onOpen});

  final Quiz quiz;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: QuizTokens.card,
        borderRadius: BorderRadius.circular(QuizTokens.rCard),
        boxShadow: QuizTokens.shadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(quiz.title, style: QuizTokens.heading(18)),
                ),
                DifficultyChip(difficulty: quiz.difficulty),
              ],
            ),
            const SizedBox(height: 8),
            Text(quiz.subject, style: QuizTokens.body(14, color: QuizTokens.muted)),
            const SizedBox(height: 14),
            Row(
              children: [
                Flexible(child: _Meta(Icons.help_outline, '${quiz.questionCount} questions')),
                const SizedBox(width: 16),
                Flexible(child: _Meta(Icons.schedule, '${quiz.estimatedMinutes} min')),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onOpen,
                child: const Text('Voir le détail'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: QuizTokens.primary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: QuizTokens.body(13, color: QuizTokens.muted, weight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
