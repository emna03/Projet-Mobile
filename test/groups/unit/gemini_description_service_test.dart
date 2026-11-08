import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studymate/features/groups/services/gemini_description_service.dart';
import 'package:studymate/features/groups/viewmodels/description_assistant_viewmodel.dart';

http.Response _ok(String text) => http.Response.bytes(
      utf8.encode(jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': text}
              ]
            }
          }
        ]
      })),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('GeminiDescriptionService', () {
    test('sends prompt with API key header and returns cleaned text',
        () async {
      late http.Request captured;
      final service = GeminiDescriptionService(
        apiKey: 'test-key',
        model: 'test-model',
        client: MockClient((req) async {
          captured = req;
          return _ok('**« Groupe dédié à Java et à la POO. »**');
        }),
      );

      final result = await service.generateDescription(
        groupName: 'Java Lovers',
        level: 'Licence 2',
        isPublic: true,
        keywords: 'POO, collections',
      );

      expect(result, 'Groupe dédié à Java et à la POO.');
      expect(captured.url.path, endsWith('/models/test-model:generateContent'));
      expect(captured.headers['x-goog-api-key'], 'test-key');
      final prompt = captured.body;
      expect(prompt, contains('Java Lovers'));
      expect(prompt, contains('Licence 2'));
      expect(prompt, contains('POO, collections'));
    });

    test('truncates output to the 300-character limit', () async {
      final long = List.filled(40, 'Une phrase assez longue.').join(' ');
      final service = GeminiDescriptionService(
        apiKey: 'k',
        client: MockClient((_) async => _ok(long)),
      );

      final result = await service.improveDescription(
        groupName: 'Algo',
        level: 'Master 1',
        currentDescription: 'Groupe pour les algorithmes',
      );

      expect(result.length, lessThanOrEqualTo(300));
      expect(result, endsWith('.'));
    });

    test('throws a friendly error when the key is missing', () async {
      final service = GeminiDescriptionService(
        apiKey: '',
        client: MockClient((_) async => fail('should not call network')),
      );
      expect(service.isConfigured, isFalse);
      expect(
        () => service.generateDescription(
            groupName: 'Java', level: 'Licence 2', isPublic: true),
        throwsA(isA<GeminiException>()),
      );
    });

    test('falls back to the next model when one is overloaded', () async {
      final calledModels = <String>[];
      final service = GeminiDescriptionService(
        apiKey: 'k',
        model: 'busy-model',
        fallbackModels: ['retired-model', 'ok-model'],
        client: MockClient((req) async {
          final model = req.url.pathSegments.last.split(':').first;
          calledModels.add(model);
          return switch (model) {
            'busy-model' => http.Response('{}', 503),
            'retired-model' => http.Response('{}', 404),
            _ => _ok('Groupe de révision Java.'),
          };
        }),
      );

      final result = await service.generateDescription(
          groupName: 'Java', level: 'Licence 2', isPublic: true);

      expect(result, 'Groupe de révision Java.');
      expect(calledModels, ['busy-model', 'retired-model', 'ok-model']);
      expect(service.lastModelUsed, 'ok-model');
    });

    test('does not try other models when the key is invalid', () async {
      var calls = 0;
      final service = GeminiDescriptionService(
        apiKey: 'bad',
        model: 'a',
        fallbackModels: ['b', 'c'],
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 403);
        }),
      );
      await expectLater(
        service.generateDescription(
            groupName: 'Java', level: 'Licence 2', isPublic: true),
        throwsA(isA<GeminiException>()
            .having((e) => e.message, 'message', contains('invalide'))),
      );
      expect(calls, 1);
    });

    test('retries without thinkingConfig when a model rejects it', () async {
      final bodies = <String>[];
      final service = GeminiDescriptionService(
        apiKey: 'k',
        model: 'old-model',
        fallbackModels: const [],
        client: MockClient((req) async {
          bodies.add(req.body);
          return req.body.contains('thinkingConfig')
              ? http.Response('{"error":{"message":"thinking not supported"}}', 400)
              : _ok('Groupe Java pour débutants.');
        }),
      );
      final result = await service.generateDescription(
          groupName: 'Java', level: 'Licence 2', isPublic: true);
      expect(result, 'Groupe Java pour débutants.');
      expect(bodies.length, 2);
    });

    test('maps HTTP errors to French messages', () async {
      final service = GeminiDescriptionService(
        apiKey: 'k',
        client: MockClient((_) async => http.Response('{}', 429)),
      );
      await expectLater(
        service.generateDescription(
            groupName: 'Java', level: 'Licence 2', isPublic: true),
        throwsA(isA<GeminiException>().having(
            (e) => e.message, 'message', contains('Quota'))),
      );
    });
  });

  group('DescriptionAssistantViewModel', () {
    test('defaults to improve mode when a description exists', () {
      final vm = DescriptionAssistantViewModel(
        groupName: 'Java',
        level: 'Licence 2',
        isPublic: true,
        currentDescription: 'Groupe Java pour débutants',
        service: GeminiDescriptionService(apiKey: 'k'),
      );
      expect(vm.mode, AssistantMode.improve);
    });

    test('exposes suggestion on success and error on failure', () async {
      var fail = false;
      final vm = DescriptionAssistantViewModel(
        groupName: 'Java',
        level: 'Licence 2',
        isPublic: true,
        currentDescription: '',
        service: GeminiDescriptionService(
          apiKey: 'k',
          client: MockClient((_) async =>
              fail ? http.Response('{}', 500) : _ok('Groupe Java convivial.')),
        ),
      );
      expect(vm.mode, AssistantMode.generate);

      await vm.submit();
      expect(vm.suggestion, 'Groupe Java convivial.');
      expect(vm.errorMessage, isNull);

      fail = true;
      await vm.submit();
      expect(vm.errorMessage, isNotNull);
      expect(vm.isLoading, isFalse);
    });
  });
}
