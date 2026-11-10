import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/quizzes/knowledge_graph/services/concept_normalizer.dart';

void main() {
  const n = ConceptNormalizer();

  test('normalise et déduplique les accents', () {
    expect(n.canonicalize('Héritage'), n.canonicalize('heritage'));
    expect(n.canonicalize('  POO  '), 'poo');
  });

  test('ids stables', () {
    final a = n.conceptIdFromCanonical(n.canonicalize('Polymorphisme'));
    final b = n.conceptIdFromCanonical(n.canonicalize('polymorphisme'));
    expect(a, b);
  });

  test('content hash change si question change', () {
    final h1 = n.contentHash(
      quizId: 'q1',
      questions: [(id: '1', text: 'A', explanation: '')],
    );
    final h2 = n.contentHash(
      quizId: 'q1',
      questions: [(id: '1', text: 'B', explanation: '')],
    );
    expect(h1, isNot(h2));
  });
}
