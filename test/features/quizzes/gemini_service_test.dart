import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studymate/features/quizzes/models/quiz.dart';
import 'package:studymate/features/quizzes/models/quiz_attempt.dart';
import 'package:studymate/features/quizzes/models/question.dart';
import 'package:studymate/features/quizzes/services/gemini_exceptions.dart';
import 'package:studymate/features/quizzes/services/gemini_service.dart';

void main() {
  test('refuse si Gemini non configuré (pas de faux résultat)', () async {
    final service = GeminiService(
      config: GeminiConfig(proxyUrl: '', apiKey: ''),
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    expect(
      () => service.generateQuiz(
        topic: 'Java',
        difficulty: QuizDifficulty.facile,
        questionCount: 5,
      ),
      throwsA(isA<GeminiNotConfiguredException>()),
    );
  });

  test('parse un JSON Gemini valide en Quiz', () async {
    final payload = {
      'candidates': [
        {
          'content': {
            'parts': [
              {
                'text': jsonEncode({
                  'title': 'Quiz Java',
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
                }),
              },
            ],
          },
        },
      ],
    };

    final service = GeminiService(
      config: GeminiConfig(apiKey: 'test-key', proxyUrl: ''),
      client: MockClient((request) async {
        expect(request.url.toString(), contains('generateContent'));
        return http.Response(jsonEncode(payload), 200);
      }),
    );

    final quiz = await service.generateQuiz(
      topic: 'Java',
      difficulty: QuizDifficulty.facile,
      questionCount: 5,
    );

    expect(quiz.title, 'Quiz Java');
    expect(quiz.questions, hasLength(5));
    expect(quiz.generatedByAi, isTrue);
    expect(quiz.questions.first.explanation, 'Parce que B.');
  });

  test('quota 429', () async {
    final service = GeminiService(
      config: GeminiConfig(apiKey: 'test-key', proxyUrl: ''),
      client: MockClient((_) async => http.Response('quota', 429)),
    );

    expect(
      () => service.generateQuiz(
        topic: 'Docker',
        difficulty: QuizDifficulty.moyen,
        questionCount: 5,
      ),
      throwsA(isA<GeminiQuotaException>()),
    );
  });

  test('analyse JSON valide', () async {
    final payload = {
      'candidates': [
        {
          'content': {
            'parts': [
              {
                'text': jsonEncode({
                  'personalizedExplanation': 'Tu confonds List et Set.',
                  'topicsToReview': ['Collections'],
                  'revisionTips': ['Revois Set', 'Fais des exercices', 'Relis le cours'],
                  'nextDifficulty': 'facile',
                }),
              },
            ],
          },
        },
      ],
    };

    final service = GeminiService(
      config: GeminiConfig(apiKey: 'k', proxyUrl: ''),
      client: MockClient((_) async => http.Response(jsonEncode(payload), 200)),
    );

    final quiz = Quiz(
      id: 'q1',
      title: 'T',
      description: 'D',
      subject: 'Java',
      difficulty: QuizDifficulty.facile,
      estimatedMinutes: 10,
      questions: [
        const Question(
          id: '1',
          text: 'Q',
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 0,
          explanation: 'A',
        ),
      ],
    );
    final attempt = QuizAttempt(
      id: 'a1',
      userId: 'u1',
      quizId: 'q1',
      quizTitle: 'T',
      subject: 'Java',
      difficulty: QuizDifficulty.facile,
      correctCount: 0,
      totalCount: 1,
      selectedAnswers: const [1],
      completedAt: DateTime(2026, 1, 1),
    );

    final analysis = await service.analyzeAttempt(quiz: quiz, attempt: attempt);
    expect(analysis.personalizedExplanation, contains('List'));
    expect(analysis.revisionTips, hasLength(3));
  });
}
