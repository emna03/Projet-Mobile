import '../../models/quiz.dart';
import '../models/knowledge_concept.dart';
import '../models/knowledge_edge.dart';
import '../models/knowledge_recommendation.dart';
import '../models/mastery_level.dart';
import '../models/question_concept_link.dart';
import '../models/student_concept_mastery.dart';

/// Moteur de décision local — recommandations basées sur données réelles.
class DecisionEngine {
  const DecisionEngine();

  List<KnowledgeRecommendation> buildRecommendations({
    required List<KnowledgeConcept> concepts,
    required List<KnowledgeEdge> edges,
    required List<StudentConceptMastery> masteries,
    required List<QuestionConceptLink> links,
    required List<Quiz> quizzes,
    int limit = 8,
  }) {
    final byId = {for (final c in concepts) c.id: c};
    final masteryByConcept = {for (final m in masteries) m.conceptId: m};
    final quizIdsByConcept = <String, Set<String>>{};
    for (final link in links) {
      quizIdsByConcept
          .putIfAbsent(link.conceptId, () => <String>{})
          .add(link.quizId);
    }

    final weak = <StudentConceptMastery>[];
    for (final c in concepts) {
      final m = masteryByConcept[c.id];
      if (m == null ||
          m.level == MasteryLevel.unevalue ||
          m.level == MasteryLevel.faible ||
          m.level == MasteryLevel.moyenne) {
        weak.add(
          m ??
              StudentConceptMastery(
                id: 'tmp',
                userId: '',
                conceptId: c.id,
                scorePercent: 0,
                level: MasteryLevel.unevalue,
                correctWeight: 0,
                totalWeight: 0,
                attemptCount: 0,
                distinctQuestions: 0,
              ),
        );
      }
    }

    weak.sort((a, b) {
      final rank = _rank(a.level).compareTo(_rank(b.level));
      if (rank != 0) return rank;
      return a.scorePercent.compareTo(b.scorePercent);
    });

    final recs = <KnowledgeRecommendation>[];
    var priority = 1;
    for (final m in weak) {
      final concept = byId[m.conceptId];
      if (concept == null) continue;

      final prereqs = edges
          .where(
            (e) =>
                e.relationType == 'prerequisite' &&
                e.toConceptId == m.conceptId,
          )
          .map((e) => e.fromConceptId)
          .where((id) {
            final pm = masteryByConcept[id];
            return pm == null ||
                pm.level == MasteryLevel.faible ||
                pm.level == MasteryLevel.unevalue ||
                pm.level == MasteryLevel.moyenne;
          })
          .toList();

      // Priorise d’abord les prérequis faibles.
      if (prereqs.isNotEmpty) {
        for (final pid in prereqs) {
          final pc = byId[pid];
          if (pc == null) continue;
          if (recs.any((r) => r.conceptId == pid)) continue;
          final pm = masteryByConcept[pid];
          recs.add(
            KnowledgeRecommendation(
              conceptId: pid,
              conceptName: pc.displayName,
              priority: priority++,
              reason:
                  'Prérequis de « ${concept.displayName} » encore fragile '
                  '(${pm?.level.label ?? 'non évalué'}).',
              currentLevel: pm?.level ?? MasteryLevel.unevalue,
              targetLevel: MasteryLevel.bonne,
              relatedQuizIds: _quizTitles(
                quizIdsByConcept[pid] ?? {},
                quizzes,
              ),
              dependentOn: const [],
            ),
          );
        }
      }

      if (recs.any((r) => r.conceptId == m.conceptId)) continue;

      final reason = switch (m.level) {
        MasteryLevel.unevalue =>
          'Concept identifié mais jamais évalué sur tes tentatives.',
        MasteryLevel.faible =>
          'Taux de réussite pondéré ${m.scorePercent.toStringAsFixed(0)}% '
              'sur ${m.distinctQuestions} question(s).',
        MasteryLevel.moyenne =>
          'Maîtrise moyenne (${m.scorePercent.toStringAsFixed(0)}%) — '
              'besoin de consolidation.',
        _ => 'À renforcer.',
      };

      recs.add(
        KnowledgeRecommendation(
          conceptId: m.conceptId,
          conceptName: concept.displayName,
          priority: priority++,
          reason: reason,
          currentLevel: m.level,
          targetLevel: MasteryLevel.bonne,
          relatedQuizIds: _quizTitles(
            quizIdsByConcept[m.conceptId] ?? {},
            quizzes,
          ),
          dependentOn: prereqs
              .map((id) => byId[id]?.displayName ?? id)
              .whereType<String>()
              .toList(),
        ),
      );

      if (recs.length >= limit) break;
    }

    return recs.take(limit).toList();
  }

  List<String> _quizTitles(Set<String> ids, List<Quiz> quizzes) {
    final byId = {for (final q in quizzes) q.id: q.title};
    return [
      for (final id in ids)
        if (byId.containsKey(id)) byId[id]! else id,
    ];
  }

  int _rank(MasteryLevel level) => switch (level) {
        MasteryLevel.unevalue => 0,
        MasteryLevel.faible => 1,
        MasteryLevel.moyenne => 2,
        MasteryLevel.bonne => 3,
        MasteryLevel.excellente => 4,
      };
}
