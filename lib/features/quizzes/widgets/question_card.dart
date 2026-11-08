import 'package:flutter/material.dart';

import '../theme/quiz_theme.dart';

class QuestionCard extends StatelessWidget {
  const QuestionCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: QuizTokens.card,
        borderRadius: BorderRadius.circular(QuizTokens.rCard),
        boxShadow: QuizTokens.shadow,
      ),
      child: Text(text, style: QuizTokens.heading(18)),
    );
  }
}
