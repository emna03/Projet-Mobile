import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/quizzes/data/quiz_repository.dart';
import 'package:studymate/features/quizzes/models/question.dart';
import 'package:studymate/features/quizzes/models/quiz.dart';
import 'package:studymate/features/quizzes/viewmodels/quiz_viewmodel.dart';

void main() {
  test('calcul déterministe du score de session', () {
    final quiz = Quiz(
      id: 'q',
      title: 'T',
      description: 'D',
      subject: 'Java',
      difficulty: QuizDifficulty.facile,
      estimatedMinutes: 10,
      questions: const [
        Question(id: '1', text: 'Q1', options: ['A', 'B', 'C', 'D'], correctIndex: 0),
        Question(id: '2', text: 'Q2', options: ['A', 'B', 'C', 'D'], correctIndex: 2),
        Question(id: '3', text: 'Q3', options: ['A', 'B', 'C', 'D'], correctIndex: 1),
      ],
    );

    final vm = QuizViewModel(
      repository: QuizRepository.memory(quizzes: [quiz], history: []),
    );
    vm.startQuiz(quiz);
    vm.selectAnswer(0);
    vm.validateAnswer();
    expect(vm.goToNextQuestion(), isFalse);
    vm.selectAnswer(0); // wrong
    vm.validateAnswer();
    expect(vm.goToNextQuestion(), isFalse);
    vm.selectAnswer(1);
    vm.validateAnswer();
    expect(vm.goToNextQuestion(), isTrue);

    final result = vm.buildSessionResult();
    expect(result.correctCount, 2);
    expect(result.totalCount, 3);
    expect(result.scorePercent, 67);
    expect(result.wrongCount, 1);
  });
}
