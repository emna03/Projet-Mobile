import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studymate/features/quizzes/models/quiz.dart';
import 'package:studymate/features/quizzes/services/openrouter_service.dart';
import 'package:studymate/features/quizzes/services/quiz_ai_provider.dart';

void main() {
  test('refuse si OpenRouter non configuré (pas de faux résultat)', () async {
    final service = OpenRouterService(
      config: OpenRouterConfig(proxyUrl: '', apiKey: ''),
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    expect(
      () => service.generateQuiz(
        topic: 'Java',
        difficulty: QuizDifficulty.facile,
        questionCount: 5,
      ),
      throwsA(
        isA<QuizAiException>().having((e) => e.code, 'code', 'not_configured'),
      ),
    );
  });

  test('parse un JSON OpenRouter chat valide en Quiz', () async {
    final quizJson = {
      'title': 'Quiz OR',
      'description': 'Bases',
      'subject': 'Java',
      'estimatedMinutes': 10,
      'questions': [
        for (var i = 0; i < 5; i++)
          {
            'text': 'Question $i ?',
            'options': ['A', 'B', 'C', 'D'],
            'correctIndex': 1,
            'explanation': 'Parce que B.',
            'difficulty': 'facile',
          },
      ],
    };

    final service = OpenRouterService(
      config: OpenRouterConfig(apiKey: 'test-key', proxyUrl: ''),
      client: MockClient((request) async {
        expect(request.url.host, 'openrouter.ai');
        expect(request.headers['Authorization'], 'Bearer test-key');
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': jsonEncode(quizJson)},
              },
            ],
          }),
          200,
        );
      }),
    );

    final quiz = await service.generateQuiz(
      topic: 'Java',
      difficulty: QuizDifficulty.facile,
      questionCount: 5,
    );

    expect(quiz.title, 'Quiz OR');
    expect(quiz.questions, hasLength(5));
    expect(quiz.generatedByAi, isTrue);
    expect(service.displayName, 'OpenRouter');
    expect(service.kind, AiProviderKind.openRouter);
  });

  test('quota 429 OpenRouter', () async {
    final service = OpenRouterService(
      config: OpenRouterConfig(apiKey: 'k', proxyUrl: ''),
      client: MockClient((_) async => http.Response('quota', 429)),
    );

    expect(
      () => service.generateQuiz(
        topic: 'Docker',
        difficulty: QuizDifficulty.moyen,
        questionCount: 5,
      ),
      throwsA(isA<QuizAiException>().having((e) => e.code, 'code', 'quota')),
    );
  });
}
