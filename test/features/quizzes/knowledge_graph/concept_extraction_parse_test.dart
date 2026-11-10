import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/quizzes/knowledge_graph/services/concept_extraction_service.dart';
import 'package:studymate/features/quizzes/models/question.dart';
import 'package:studymate/features/quizzes/models/quiz.dart';
import 'package:studymate/features/quizzes/services/quiz_ai_provider.dart';

Quiz _quiz() => Quiz(
      id: 'q-parse',
      title: 'Réseaux',
      description: '',
      subject: 'Réseaux',
      difficulty: QuizDifficulty.moyen,
      estimatedMinutes: 10,
      questions: const [
        Question(
          id: 'q1',
          text: 'Qu’est-ce qu’une adresse IP ?',
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 0,
          explanation: 'Identifiant réseau',
        ),
        Question(
          id: 'q2',
          text: 'Le rôle du DNS ?',
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 1,
          explanation: 'Résolution de noms',
        ),
      ],
    );

void main() {
  final svc = ConceptExtractionService();

  test('stripLlmWrappers retire markdown et ChatML', () {
    const raw = '''
<|im_start|>assistant
Voici le JSON :
```json
{"concepts":[{"name":"DNS","questionIds":["q2"]}],"relations":[]}
```
<|im_end|>
''';
    final cleaned = ConceptExtractionService.stripLlmWrappers(raw);
    expect(cleaned.startsWith('{'), isTrue);
    expect(cleaned.contains('```'), isFalse);
    expect(cleaned.contains('<|im'), isFalse);
  });

  test('parseAiPayload accepte JSON propre', () {
    const raw =
        '{"concepts":[{"name":"Adresse IP","questionIds":["q1"]},{"name":"DNS","questionIds":["q2"]}],'
        '"relations":[{"from":"Adresse IP","to":"DNS","type":"related"}]}';
    final r = svc.parseAiPayload(raw, _quiz());
    expect(r.source, 'ai');
    expect(r.concepts.length, 2);
    expect(r.relations.length, 1);
  });

  test('parseAiPayload accepte JSON entouré de prose', () {
    const raw = 'Bien sûr !\n{"concepts":[{"name":"DNS","questionIds":["q2"]}],"relations":[]}\nFin.';
    final r = svc.parseAiPayload(raw, _quiz());
    expect(r.concepts.single.name.toUpperCase(), 'DNS');
  });

  test('parseAiPayload recovery partielle sans inventer de concepts', () {
    // Tronqué après le 1er concept complet.
    const raw =
        '{"concepts":[{"name":"Adresse IP","questionIds":["q1"]},{"name":"DNS","questionIds":';
    final r = svc.parseAiPayload(raw, _quiz());
    expect(r.concepts.length, 1);
    expect(r.concepts.first.name.toLowerCase(), contains('adresse'));
    expect(r.relations, isEmpty);
  });

  test('parseAiPayload refuse JSON sans concept (pas de faux succès)', () {
    expect(
      () => svc.parseAiPayload('{"concepts":[],"relations":[]}', _quiz()),
      throwsA(isA<QuizAiException>()),
    );
  });

  test('buildExtractionPrompt reste court et borné', () {
    final p = svc.buildExtractionPrompt(_quiz());
    expect(p.length, lessThan(1600));
    expect(p.toLowerCase(), contains('json'));
    expect(p, contains('id=q1'));
    expect(p, contains('INTERDIT'));
  });

  test('encodeResultPayload round-trip parse', () {
    final first = svc.parseAiPayload(
      '{"concepts":[{"name":"DNS","questionIds":["q2"]}],"relations":[]}',
      _quiz(),
    );
    final encoded = svc.encodeResultPayload(first);
    final second = svc.parseAiPayload(encoded, _quiz());
    expect(second.concepts.single.name, first.concepts.single.name);
  });
}
