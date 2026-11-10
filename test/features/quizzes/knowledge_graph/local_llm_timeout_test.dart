import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/quizzes/knowledge_graph/services/local_llm/local_knowledge_llm_service.dart';

void main() {
  test('isAlreadyLoadedError reconnaît le StateError du plugin', () {
    expect(
      LocalKnowledgeLlmService.isAlreadyLoadedError(
        StateError('Model already loaded'),
      ),
      isTrue,
    );
    expect(
      LocalKnowledgeLlmService.isAlreadyLoadedError(
        StateError('Bad state: Model already loaded'),
      ),
      isTrue,
    );
    expect(
      LocalKnowledgeLlmService.isAlreadyLoadedError(
        Exception('OOM'),
      ),
      isFalse,
    );
  });

  test('timeout : infer: timeout + verrou libéré', () async {
    final hang = StreamController<String>();
    addTearDown(() async {
      if (!hang.isClosed) await hang.close();
    });

    final svc = LocalKnowledgeLlmService(
      inferenceTimeout: const Duration(milliseconds: 80),
      generateStreamOverride: ({
        required String prompt,
        required int maxTokens,
        required double temperature,
      }) =>
          hang.stream,
    );

    expect(svc.isInferenceGateIdle, isTrue);

    Object? caught;
    try {
      await svc.complete('prompt-hang');
    } catch (e) {
      caught = e;
    }

    expect(caught, isA<StateError>());
    expect(caught.toString(), contains('infer: timeout'));
    expect(svc.lastFailureSummary, contains('infer: timeout'));
    expect(svc.isInferenceGateIdle, isTrue);
  });

  test('après timeout, une génération suivante peut s’exécuter', () async {
    var call = 0;
    final hang = StreamController<String>();
    addTearDown(() async {
      if (!hang.isClosed) await hang.close();
    });

    final svc = LocalKnowledgeLlmService(
      inferenceTimeout: const Duration(milliseconds: 60),
      generateStreamOverride: ({
        required String prompt,
        required int maxTokens,
        required double temperature,
      }) {
        call++;
        if (call == 1) return hang.stream;
        return Stream<String>.value('{"concepts":[]}');
      },
    );

    await expectLater(
      svc.complete('first'),
      throwsA(
        isA<StateError>().having(
          (e) => e.toString(),
          'message',
          contains('infer: timeout'),
        ),
      ),
    );
    expect(svc.isInferenceGateIdle, isTrue);

    final second = await svc.complete('second');
    expect(second, contains('concepts'));
    expect(call, 2);
    expect(svc.isInferenceGateIdle, isTrue);
  });

  test('callbacks tardifs après timeout n’écrasent pas le résultat suivant',
      () async {
    final hang = StreamController<String>();
    addTearDown(() async {
      if (!hang.isClosed) await hang.close();
    });

    final svc = LocalKnowledgeLlmService(
      inferenceTimeout: const Duration(milliseconds: 50),
      generateStreamOverride: ({
        required String prompt,
        required int maxTokens,
        required double temperature,
      }) {
        if (prompt == 'hang') return hang.stream;
        return Stream<String>.fromIterable(['OK-', 'DONE']);
      },
    );

    await expectLater(svc.complete('hang'), throwsA(isA<StateError>()));

    // Événements tardifs sur l’ancien stream (ne doivent pas corrompre).
    hang.add('LATE_CHUNK');
    await hang.close();

    final ok = await svc.complete('ok');
    expect(ok, 'OK-DONE');
    expect(svc.lastFailureSummary, isNull);
    expect(svc.isInferenceGateIdle, isTrue);
  });

  test('génération normale se termine avant le timeout', () async {
    final svc = LocalKnowledgeLlmService(
      inferenceTimeout: const Duration(seconds: 5),
      generateStreamOverride: ({
        required String prompt,
        required int maxTokens,
        required double temperature,
      }) =>
          Stream<String>.fromIterable(['hello', ' ', 'world']),
    );

    final text = await svc.complete('p');
    expect(text, 'hello world');
    expect(svc.isInferenceGateIdle, isTrue);
  });

  test('générations successives : 3 completes sérialisées OK', () async {
    var n = 0;
    final svc = LocalKnowledgeLlmService(
      inferenceTimeout: const Duration(seconds: 2),
      generateStreamOverride: ({
        required String prompt,
        required int maxTokens,
        required double temperature,
      }) {
        n++;
        return Stream<String>.value('{"ok":$n,"prompt":"$prompt"}');
      },
    );

    final a = await svc.complete('a');
    final b = await svc.complete('b');
    final c = await svc.complete('c');
    expect(a, contains('"ok":1'));
    expect(b, contains('"ok":2'));
    expect(c, contains('"ok":3'));
    expect(n, 3);
    expect(svc.isInferenceGateIdle, isTrue);
  });

  test('sérialisation : 2e appel attend la fin / timeout du 1er', () async {
    final hang = StreamController<String>();
    addTearDown(() async {
      if (!hang.isClosed) await hang.close();
    });
    final order = <String>[];

    final svc = LocalKnowledgeLlmService(
      inferenceTimeout: const Duration(milliseconds: 100),
      generateStreamOverride: ({
        required String prompt,
        required int maxTokens,
        required double temperature,
      }) {
        order.add('start:$prompt');
        if (prompt == 'a') return hang.stream;
        return Stream<String>.value('b-ok');
      },
    );

    final a = svc.complete('a');
    final b = svc.complete('b');

    await expectLater(a, throwsA(isA<StateError>()));
    expect(await b, 'b-ok');
    expect(order, ['start:a', 'start:b']);
    expect(svc.isInferenceGateIdle, isTrue);
  });
}
