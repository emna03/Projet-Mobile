import 'package:flutter/material.dart';

import '../models/quiz_result.dart';
import '../theme/quiz_theme.dart';
import '../viewmodels/quiz_viewmodel.dart';
import '../widgets/difficulty_chip.dart';

class QuizHistoryPage extends StatelessWidget {
  const QuizHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final results = QuizScope.of(context).history;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Historique'),
      ),
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text('Historique des quiz', style: QuizTokens.heading(24)),
            const SizedBox(height: 4),
            Text(
              'Les scores de cette session s’ajoutent à la liste.',
              style: QuizTokens.body(14, color: QuizTokens.muted),
            ),
            const SizedBox(height: 20),
            for (final result in results) ...[
              _HistoryCard(result: result),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.result});

  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final percent = result.scorePercent;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: QuizTokens.card,
        borderRadius: BorderRadius.circular(QuizTokens.rCard),
        boxShadow: QuizTokens.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(result.quizTitle, style: QuizTokens.heading(17))),
              DifficultyChip(difficulty: result.difficulty),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${result.subject} · ${result.dateLabel}',
            style: QuizTokens.body(13, color: QuizTokens.muted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                '$percent %',
                style: QuizTokens.heading(20).copyWith(
                  color: percent >= 80 ? QuizTokens.success : QuizTokens.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 8,
                    color: percent >= 80 ? QuizTokens.success : QuizTokens.accent,
                    backgroundColor: QuizTokens.primarySoft,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
