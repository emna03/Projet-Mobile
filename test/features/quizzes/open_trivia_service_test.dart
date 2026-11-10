import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studymate/features/quizzes/models/quiz.dart';
import 'package:studymate/features/quizzes/services/open_trivia_service.dart';

void main() {
  test('convertit Open Trivia en modèle Quiz et décode HTML', () async {
    final body = {
      'response_code': 0,
      'results': [
        {
          'category': 'Science: Computers',
          'type': 'multiple',
          'difficulty': 'easy',
          'question': 'What does CPU stand for?',
          'correct_answer': 'Central Processing Unit',
          'incorrect_answers': [
            'Central Process Unit',
            'Computer Personal Unit',
            'Central Processor Unit',
          ],
        },
        {
          'question': 'HTML &amp; CSS',
          'correct_answer': 'A &amp; B',
          'incorrect_answers': ['X', 'Y', 'Z'],
        },
        {
          'question': 'Q3',
          'correct_answer': 'C',
          'incorrect_answers': ['A', 'B', 'D'],
        },
        {
          'question': 'Q4',
          'correct_answer': 'C',
          'incorrect_answers': ['A', 'B', 'D'],
        },
        {
          'question': 'Q5',
          'correct_answer': 'C',
          'incorrect_answers': ['A', 'B', 'D'],
        },
      ],
    };

    final service = OpenTriviaService(
      client: MockClient((request) async {
        expect(request.url.host, 'opentdb.com');
        return http.Response(jsonEncode(body), 200);
      }),
    );

    final quiz = await service.fetchQuiz(
      amount: 5,
      difficulty: QuizDifficulty.facile,
      categoryId: 18,
    );

    expect(quiz.questions.length, greaterThanOrEqualTo(5));
    expect(quiz.questions.any((q) => q.text.contains('HTML & CSS')), isTrue);
    expect(quiz.questions.first.options, hasLength(4));
  });

  test('erreurs response_code non nul', () async {
    final service = OpenTriviaService(
      client: MockClient(
        (_) async => http.Response(jsonEncode({'response_code': 1, 'results': []}), 200),
      ),
    );

    expect(
      () => service.fetchQuiz(amount: 5, difficulty: QuizDifficulty.moyen),
      throwsA(isA<OpenTriviaException>()),
    );
  });
}
