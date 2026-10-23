import 'package:flutter/material.dart';

import '../theme/quiz_theme.dart';
import '../viewmodels/quiz_viewmodel.dart';
import 'quiz_play_page.dart';

class QuizResultPage extends StatelessWidget {
  const QuizResultPage({super.key});

  String _message(int percent) {
    if (percent >= 80) return 'Excellent travail, continuez ainsi.';
    if (percent >= 60) return 'Bon score, quelques révisions suffiront.';
    return 'Reprenez le quiz pour consolider vos acquis.';
  }

  @override
  Widget build(BuildContext context) {
    final vm = QuizScope.of(context);
    final result = vm.buildSessionResult();
    final percent = result.scorePercent;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        title: const Text('Résultats'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Text('Félicitations', style: QuizTokens.heading(26)),
                  const SizedBox(height: 6),
                  Text(
                    'Vous avez terminé « ${result.quizTitle} ».',
                    style: QuizTokens.body(15, color: QuizTokens.muted),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: CircularProgressIndicator(
                              value: percent / 100,
                              strokeWidth: 12,
                              color: percent >= 70 ? QuizTokens.success : QuizTokens.accent,
                              backgroundColor: QuizTokens.primarySoft,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$percent %', style: QuizTokens.heading(32)),
                              Text('Score', style: QuizTokens.body(13, color: QuizTokens.muted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _StatCard(
                    correct: result.correctCount,
                    wrong: result.wrongCount,
                    total: result.totalCount,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: QuizTokens.card,
                      borderRadius: BorderRadius.circular(QuizTokens.rCard),
                      boxShadow: QuizTokens.shadow,
                    ),
                    child: Text(
                      _message(percent),
                      style: QuizTokens.body(15),
                    ),
                  ),
                ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      vm.retryCurrentQuiz();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(builder: (_) => const QuizPlayPage()),
                      );
                    },
                    child: const Text('Refaire le quiz'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    child: Text(
                      'Retour vers les quiz',
                      style: QuizTokens.body(15, color: QuizTokens.primary, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.correct, required this.wrong, required this.total});

  final int correct;
  final int wrong;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: QuizTokens.card,
        borderRadius: BorderRadius.circular(QuizTokens.rCard),
        boxShadow: QuizTokens.shadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(label: 'Bonnes', value: '$correct / $total', color: QuizTokens.success),
          ),
          Container(width: 1, height: 44, color: QuizTokens.border),
          Expanded(
            child: _Stat(label: 'Mauvaises', value: '$wrong', color: QuizTokens.danger),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: QuizTokens.heading(20).copyWith(color: color)),
        const SizedBox(height: 4),
        Text(label, style: QuizTokens.body(13, color: QuizTokens.muted)),
      ],
    );
  }
}
