import 'package:flutter/material.dart';

import '../theme/quiz_theme.dart';
import '../viewmodels/quiz_viewmodel.dart';
import '../widgets/answer_option.dart';
import '../widgets/question_card.dart';
import 'quiz_result_page.dart';

class QuizPlayPage extends StatelessWidget {
  const QuizPlayPage({super.key});

  AnswerVisualState _state(QuizViewModel vm, int index) {
    final question = vm.currentQuestion;
    if (question == null) return AnswerVisualState.idle;
    if (vm.answerValidated) {
      if (index == question.correctIndex) return AnswerVisualState.correct;
      if (index == vm.selectedAnswer) return AnswerVisualState.incorrect;
      return AnswerVisualState.idle;
    }
    if (index == vm.selectedAnswer) return AnswerVisualState.selected;
    return AnswerVisualState.idle;
  }

  Future<void> _onPrimary(BuildContext context, QuizViewModel vm) async {
    if (!vm.answerValidated) {
      vm.validateAnswer();
      return;
    }
    final finished = vm.goToNextQuestion();
    if (finished && context.mounted) {
      vm.completeSession();
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const QuizResultPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = QuizScope.of(context);
    final quiz = vm.sessionQuiz;
    final question = vm.currentQuestion;

    if (quiz == null || question == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton(), title: const Text('Quiz')),
        body: const Center(child: Text('Aucun quiz en cours.')),
      );
    }

    final remainingMinutes =
        ((1 - vm.playProgress) * quiz.estimatedMinutes).ceil().clamp(1, quiz.estimatedMinutes);
    final lastQuestion = vm.questionIndex + 1 >= quiz.questions.length;
    final label = !vm.answerValidated
        ? 'Valider'
        : (lastQuestion ? 'Voir les résultats' : 'Question suivante');

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(quiz.title),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Row(
                    children: [
                      Text(
                        'Question ${vm.questionIndex + 1} / ${quiz.questions.length}',
                        style: QuizTokens.body(14, weight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Icon(Icons.timer_outlined, size: 18, color: QuizTokens.muted),
                      const SizedBox(width: 6),
                      Text(
                        '~ $remainingMinutes min',
                        style: QuizTokens.body(13, color: QuizTokens.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: vm.playProgress,
                      minHeight: 8,
                      color: QuizTokens.primary,
                      backgroundColor: QuizTokens.primarySoft,
                    ),
                  ),
                  const SizedBox(height: 20),
                  QuestionCard(text: question.text),
                  const SizedBox(height: 16),
                  for (var k = 0; k < question.options.length; k++) ...[
                    AnswerOption(
                      index: k,
                      label: question.options[k],
                      state: _state(vm, k),
                      onTap: () => vm.selectAnswer(k),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                16 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: vm.selectedAnswer == null && !vm.answerValidated
                      ? null
                      : () => _onPrimary(context, vm),
                  child: Text(label),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
