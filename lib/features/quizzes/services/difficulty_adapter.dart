import '../models/ai_analysis.dart';
import '../models/quiz.dart';
import '../models/quiz_attempt.dart';
import '../models/question.dart';

/// Adaptation déterministe de la difficulté (sans inventer de score).
class DifficultyAdapter {
  const DifficultyAdapter();

  /// Règle locale à partir du score de la dernière tentative.
  QuizDifficulty fromScore({
    required QuizDifficulty current,
    required int scorePercent,
  }) {
    if (scorePercent >= 80) {
      return _stepUp(current);
    }
    if (scorePercent < 50) {
      return _stepDown(current);
    }
    return current;
  }

  /// Moyenne des N dernières tentatives (même matière si fournie).
  QuizDifficulty fromHistory({
    required List<QuizAttempt> attempts,
    String? subject,
    QuizDifficulty fallback = QuizDifficulty.moyen,
    int lookback = 3,
  }) {
    var filtered = attempts;
    if (subject != null && subject.trim().isNotEmpty) {
      final subjectLower = subject.trim().toLowerCase();
      filtered = attempts
          .where((a) => a.subject.toLowerCase() == subjectLower)
          .toList();
    }
    if (filtered.isEmpty) return fallback;

    final recent = filtered.take(lookback).toList();
    final avg = recent.map((a) => a.scorePercent).reduce((a, b) => a + b) /
        recent.length;
    final lastDifficulty = recent.first.difficulty;
    return fromScore(current: lastDifficulty, scorePercent: avg.round());
  }

  /// Combine règle locale + suggestion IA (si valide).
  QuizDifficulty resolve({
    required QuizDifficulty current,
    required int scorePercent,
    AiAnalysis? analysis,
  }) {
    final local = fromScore(current: current, scorePercent: scorePercent);
    if (analysis == null) return local;

    final ai = quizDifficultyFromName(analysis.nextDifficulty);
    // Si l'IA et la règle locale divergent d'un cran, on privilégie la plus prudente
    // (plus facile) pour éviter de frustrer l'étudiant.
    if (_rank(ai) <= _rank(local)) return ai;
    return local;
  }

  QuizDifficulty _stepUp(QuizDifficulty d) => switch (d) {
        QuizDifficulty.facile => QuizDifficulty.moyen,
        QuizDifficulty.moyen => QuizDifficulty.difficile,
        QuizDifficulty.difficile => QuizDifficulty.difficile,
      };

  QuizDifficulty _stepDown(QuizDifficulty d) => switch (d) {
        QuizDifficulty.difficile => QuizDifficulty.moyen,
        QuizDifficulty.moyen => QuizDifficulty.facile,
        QuizDifficulty.facile => QuizDifficulty.facile,
      };

  int _rank(QuizDifficulty d) => switch (d) {
        QuizDifficulty.facile => 0,
        QuizDifficulty.moyen => 1,
        QuizDifficulty.difficile => 2,
      };
}
