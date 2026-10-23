import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/quizzes/data/quiz_repository.dart';
import 'package:studymate/features/quizzes/models/question.dart';
import 'package:studymate/features/quizzes/models/quiz.dart';
import 'package:studymate/features/quizzes/viewmodels/quiz_viewmodel.dart';

Question _q(String id) => Question(
      id: id,
      text: 'Énoncé $id',
      options: const ['A', 'B', 'C', 'D'],
      correctIndex: 0,
    );

Quiz _quiz({String id = '', String title = 'Quiz test'}) => Quiz(
      id: id,
      title: title,
      description: 'Desc',
      subject: 'Java',
      difficulty: QuizDifficulty.facile,
      estimatedMinutes: 10,
      questions: [_q('1')],
    );

void main() {
  test('create, read, update, delete un quiz', () {
    final repository = QuizRepository(quizzes: [], history: []);

    final created = repository.create(_quiz());
    expect(created.id, isNotEmpty);
    expect(repository.getAll(), hasLength(1));
    expect(repository.getById(created.id)?.title, 'Quiz test');

    final updated = repository.update(created.copyWith(title: 'Quiz modifié'));
    expect(repository.getById(created.id)?.title, 'Quiz modifié');
    expect(updated.title, 'Quiz modifié');

    expect(repository.delete(created.id), isTrue);
    expect(repository.getById(created.id), isNull);
    expect(repository.getAll(), isEmpty);
  });

  test('le ViewModel refuse un quiz sans titre', () {
    final vm = QuizViewModel(repository: QuizRepository(quizzes: [], history: []));
    final saved = vm.createQuiz(_quiz(title: '  '));
    expect(saved, isNull);
    expect(vm.errorMessage, isNotNull);
    expect(vm.quizzes, isEmpty);
  });

  test('le ViewModel crée un quiz valide', () {
    final vm = QuizViewModel(repository: QuizRepository(quizzes: [], history: []));
    final saved = vm.createQuiz(_quiz(title: 'POO Java'));
    expect(saved, isNotNull);
    expect(vm.quizzes.single.title, 'POO Java');
  });
}
