import 'package:flutter/material.dart';

import '../models/quiz.dart';
import '../theme/quiz_theme.dart';
import '../viewmodels/quiz_viewmodel.dart';
import 'quiz_play_page.dart';

class QuizResultPage extends StatefulWidget {
  const QuizResultPage({super.key});

  @override
  State<QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends State<QuizResultPage> {
  bool _persisting = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = QuizScope.of(context);
      if (vm.lastAttempt == null) {
        await vm.completeSession();
      }
      if (mounted) setState(() => _persisting = false);
    });
  }

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
    final quiz = vm.sessionQuiz;
    final progress = vm.progressForCurrentQuiz();

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        title: const Text('Résultats'),
      ),
      body: _persisting
          ? const Center(child: Text('Enregistrement des résultats…'))
          : Column(
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
                      if (progress != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          progress >= 0
                              ? 'Progression : +$progress pts vs tentative précédente'
                              : 'Progression : $progress pts vs tentative précédente',
                          style: QuizTokens.body(14, weight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: QuizTokens.card,
                          borderRadius: BorderRadius.circular(QuizTokens.rCard),
                          boxShadow: QuizTokens.shadow,
                        ),
                        child: Text(_message(percent), style: QuizTokens.body(15)),
                      ),
                      if (quiz != null) ...[
                        const SizedBox(height: 20),
                        Text('Détail des réponses', style: QuizTokens.heading(18)),
                        const SizedBox(height: 10),
                        for (var i = 0; i < quiz.questions.length; i++)
                          _AnswerReview(
                            index: i,
                            questionText: quiz.questions[i].text,
                            selected: i < vm.sessionAnswers.length ? vm.sessionAnswers[i] : null,
                            correctIndex: quiz.questions[i].correctIndex,
                            options: quiz.questions[i].options,
                            explanation: quiz.questions[i].explanation,
                          ),
                      ],
                      const SizedBox(height: 20),
                      Text('Analyse intelligente', style: QuizTokens.heading(18)),
                      const SizedBox(height: 8),
                      if (vm.lastAnalysis != null) ...[
                        Text(vm.lastAnalysis!.personalizedExplanation, style: QuizTokens.body(14)),
                        const SizedBox(height: 8),
                        Text('Notions à revoir', style: QuizTokens.body(14, weight: FontWeight.w700)),
                        for (final topic in vm.lastAnalysis!.topicsToReview)
                          Text('• $topic', style: QuizTokens.body(14)),
                        const SizedBox(height: 8),
                        Text('Conseils', style: QuizTokens.body(14, weight: FontWeight.w700)),
                        for (final tip in vm.lastAnalysis!.revisionTips)
                          Text('• $tip', style: QuizTokens.body(14)),
                        const SizedBox(height: 8),
                        Text(
                          'Prochaine difficulté recommandée : ${vm.lastAnalysis!.nextDifficulty}',
                          style: QuizTokens.body(14, weight: FontWeight.w600),
                        ),
                      ] else
                        Text(
                          vm.activeAiConfigured
                              ? 'Lancez l’analyse ${vm.activeAiLabel} basée sur vos réponses réelles.'
                              : 'Activez la génération intelligente pour obtenir une analyse pédagogique personnalisée.',
                          style: QuizTokens.body(13, color: QuizTokens.muted),
                        ),
                      if (vm.suggestedDifficulty != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: QuizTokens.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Difficulté adaptée automatiquement : ${vm.suggestedDifficulty!.label}'
                            '${vm.difficultySuggestionReason != null ? '\n${vm.difficultySuggestionReason}' : ''}',
                            style: QuizTokens.body(13, weight: FontWeight.w600),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: vm.isAnalyzing
                            ? null
                            : () async {
                                await vm.analyzeLastAttempt();
                                if (!context.mounted) return;
                                if (vm.errorMessage != null && vm.lastAnalysis == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: QuizTokens.danger,
                                      content: Text(vm.errorMessage!),
                                    ),
                                  );
                                }
                              },
                        child: Text(
                          vm.isAnalyzing
                              ? 'Analyse…'
                              : 'Analyser mes erreurs (${vm.activeAiLabel})',
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
                          child: const Text('Rejouer'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).popUntil((route) => route.isFirst),
                          child: const Text('Retour à mes quiz'),
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

class _AnswerReview extends StatelessWidget {
  const _AnswerReview({
    required this.index,
    required this.questionText,
    required this.selected,
    required this.correctIndex,
    required this.options,
    required this.explanation,
  });

  final int index;
  final String questionText;
  final int? selected;
  final int correctIndex;
  final List<String> options;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final ok = selected == correctIndex;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: QuizTokens.card,
        borderRadius: BorderRadius.circular(QuizTokens.rCard),
        border: Border.all(color: ok ? QuizTokens.success : QuizTokens.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Q${index + 1}. $questionText', style: QuizTokens.body(14, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Votre réponse : ${selected == null || selected! < 0 || selected! >= options.length ? '—' : options[selected!]}',
            style: QuizTokens.body(13),
          ),
          Text('Bonne réponse : ${options[correctIndex]}', style: QuizTokens.body(13)),
          if (explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(explanation, style: QuizTokens.body(12, color: QuizTokens.muted)),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.correct,
    required this.wrong,
    required this.total,
  });

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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item('$correct', 'Bonnes', QuizTokens.success),
          _item('$wrong', 'Erreurs', QuizTokens.danger),
          _item('$total', 'Total', QuizTokens.primary),
        ],
      ),
    );
  }

  Widget _item(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: QuizTokens.heading(22).copyWith(color: color)),
        Text(label, style: QuizTokens.body(12, color: QuizTokens.muted)),
      ],
    );
  }
}
