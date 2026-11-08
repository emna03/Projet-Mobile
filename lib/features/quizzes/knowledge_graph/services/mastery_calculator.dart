import 'dart:math' as math;

import '../../models/quiz.dart';
import '../models/mastery_level.dart';
import '../models/student_concept_mastery.dart';

/// Observation pondérée d’une réponse liée à un concept.
class ConceptEvidence {
  const ConceptEvidence({
    required this.questionId,
    required this.correct,
    required this.difficulty,
    required this.completedAt,
    this.linkWeight = 1.0,
    this.responseSeconds,
  });

  final String questionId;
  final bool correct;
  final QuizDifficulty difficulty;
  final DateTime completedAt;
  final double linkWeight;
  final double? responseSeconds;
}

/// Algorithme local, déterministe et configurable.
class MasteryCalculator {
  const MasteryCalculator({
    this.recencyHalfLifeDays = 30,
    this.minDistinctQuestionsForBonne = 2,
    this.minAttemptsForBonne = 3,
    this.minDistinctQuestionsForExcellente = 3,
  });

  final double recencyHalfLifeDays;
  final int minDistinctQuestionsForBonne;
  final int minAttemptsForBonne;
  final int minDistinctQuestionsForExcellente;

  double difficultyWeight(QuizDifficulty d) => switch (d) {
        QuizDifficulty.facile => 0.85,
        QuizDifficulty.moyen => 1.0,
        QuizDifficulty.difficile => 1.25,
      };

  double recencyWeight(DateTime completedAt, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final days = ref.difference(completedAt).inHours / 24.0;
    if (days <= 0) return 1.0;
    return math.pow(0.5, days / recencyHalfLifeDays).toDouble().clamp(0.15, 1.0);
  }

  double responseTimeFactor(double? seconds) {
    if (seconds == null || seconds <= 0) return 1.0;
    if (seconds > 90) return 0.9;
    if (seconds < 5) return 0.95;
    return 1.0;
  }

  StudentConceptMastery compute({
    required String userId,
    required String conceptId,
    required List<ConceptEvidence> evidence,
    DateTime? now,
  }) {
    final id = 'm-$userId-$conceptId';
    if (evidence.isEmpty) {
      return StudentConceptMastery(
        id: id,
        userId: userId,
        conceptId: conceptId,
        scorePercent: 0,
        level: MasteryLevel.unevalue,
        correctWeight: 0,
        totalWeight: 0,
        attemptCount: 0,
        distinctQuestions: 0,
        updatedAt: now ?? DateTime.now(),
      );
    }

    var correctW = 0.0;
    var totalW = 0.0;
    final questionIds = <String>{};
    DateTime? lastAt;

    for (final e in evidence) {
      questionIds.add(e.questionId);
      final w = e.linkWeight *
          difficultyWeight(e.difficulty) *
          recencyWeight(e.completedAt, now: now) *
          responseTimeFactor(e.responseSeconds);
      totalW += w;
      if (e.correct) correctW += w;
      if (lastAt == null || e.completedAt.isAfter(lastAt)) {
        lastAt = e.completedAt;
      }
    }

    final score = totalW <= 0 ? 0.0 : (correctW / totalW) * 100.0;
    final level = classify(
      scorePercent: score,
      distinctQuestions: questionIds.length,
      attemptCount: evidence.length,
    );

    return StudentConceptMastery(
      id: id,
      userId: userId,
      conceptId: conceptId,
      scorePercent: double.parse(score.toStringAsFixed(2)),
      level: level,
      correctWeight: double.parse(correctW.toStringAsFixed(4)),
      totalWeight: double.parse(totalW.toStringAsFixed(4)),
      attemptCount: evidence.length,
      distinctQuestions: questionIds.length,
      lastAttemptAt: lastAt,
      updatedAt: now ?? DateTime.now(),
    );
  }

  MasteryLevel classify({
    required double scorePercent,
    required int distinctQuestions,
    required int attemptCount,
  }) {
    if (attemptCount == 0 || distinctQuestions == 0) {
      return MasteryLevel.unevalue;
    }
    if (scorePercent < 50) return MasteryLevel.faible;
    if (scorePercent < 70) return MasteryLevel.moyenne;

    final enoughForBonne = distinctQuestions >= minDistinctQuestionsForBonne ||
        attemptCount >= minAttemptsForBonne;
    if (!enoughForBonne) return MasteryLevel.moyenne;

    if (scorePercent >= 85 &&
        distinctQuestions >= minDistinctQuestionsForExcellente) {
      return MasteryLevel.excellente;
    }
    if (scorePercent >= 70) return MasteryLevel.bonne;
    return MasteryLevel.moyenne;
  }
}
