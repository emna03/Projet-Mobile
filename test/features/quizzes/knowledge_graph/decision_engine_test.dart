import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/quizzes/knowledge_graph/models/knowledge_concept.dart';
import 'package:studymate/features/quizzes/knowledge_graph/models/knowledge_edge.dart';
import 'package:studymate/features/quizzes/knowledge_graph/models/mastery_level.dart';
import 'package:studymate/features/quizzes/knowledge_graph/models/student_concept_mastery.dart';
import 'package:studymate/features/quizzes/knowledge_graph/services/decision_engine.dart';

void main() {
  test('priorise les concepts faibles et prérequis', () {
    const engine = DecisionEngine();
    final concepts = [
      const KnowledgeConcept(id: 'c1', canonicalName: 'classes', displayName: 'Classes'),
      const KnowledgeConcept(id: 'c2', canonicalName: 'heritage', displayName: 'Héritage'),
    ];
    final edges = [
      const KnowledgeEdge(
        id: 'e1',
        fromConceptId: 'c1',
        toConceptId: 'c2',
        relationType: 'prerequisite',
        justification: 'test',
      ),
    ];
    final masteries = [
      StudentConceptMastery(
        id: 'm1',
        userId: 'u',
        conceptId: 'c1',
        scorePercent: 40,
        level: MasteryLevel.faible,
        correctWeight: 1,
        totalWeight: 3,
        attemptCount: 3,
        distinctQuestions: 2,
      ),
      StudentConceptMastery(
        id: 'm2',
        userId: 'u',
        conceptId: 'c2',
        scorePercent: 35,
        level: MasteryLevel.faible,
        correctWeight: 1,
        totalWeight: 3,
        attemptCount: 3,
        distinctQuestions: 2,
      ),
    ];

    final recs = engine.buildRecommendations(
      concepts: concepts,
      edges: edges,
      masteries: masteries,
      links: const [],
      quizzes: const [],
    );

    expect(recs, isNotEmpty);
    expect(recs.first.reason.toLowerCase(), contains('prérequis'));
  });
}
