import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/ai_analysis.dart';
import '../models/quiz.dart';
import '../models/quiz_attempt.dart';
import '../theme/quiz_theme.dart';
import '../viewmodels/quiz_viewmodel.dart';

class QuizResultsHubPage extends StatelessWidget {
  const QuizResultsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = QuizScope.of(context);
    final attempts = vm.attempts;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Mes résultats'),
      ),
      body: SafeArea(
        child: attempts.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Aucune tentative enregistrée pour ${vm.currentUserId ?? 'cet utilisateur'}.',
                    textAlign: TextAlign.center,
                    style: QuizTokens.body(15, color: QuizTokens.muted),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                itemCount: attempts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final attempt = attempts[index];
                  return _AttemptCard(attempt: attempt);
                },
              ),
      ),
    );
  }
}

class _AttemptCard extends StatelessWidget {
  const _AttemptCard({required this.attempt});
  final QuizAttempt attempt;

  @override
  Widget build(BuildContext context) {
    AiAnalysis? analysis;
    if (attempt.aiAnalysisJson != null && attempt.aiAnalysisJson!.isNotEmpty) {
      try {
        analysis = AiAnalysis.fromJson(
          jsonDecode(attempt.aiAnalysisJson!) as Map<String, dynamic>,
        );
      } catch (_) {
        analysis = null;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
              Expanded(child: Text(attempt.quizTitle, style: QuizTokens.heading(17))),
              Text(
                '${attempt.scorePercent} %',
                style: QuizTokens.body(
                  16,
                  weight: FontWeight.w700,
                  color: attempt.scorePercent >= 70 ? QuizTokens.success : QuizTokens.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${attempt.subject} · ${attempt.difficulty.label} · ${attempt.source}',
            style: QuizTokens.body(13, color: QuizTokens.muted),
          ),
          const SizedBox(height: 6),
          Text(
            '${attempt.correctCount}/${attempt.totalCount} · ${attempt.completedAt}',
            style: QuizTokens.body(13),
          ),
          if (analysis != null) ...[
            const SizedBox(height: 10),
            Text('Analyse IA', style: QuizTokens.body(13, weight: FontWeight.w700)),
            Text(analysis.personalizedExplanation, style: QuizTokens.body(13)),
          ],
        ],
      ),
    );
  }
}
