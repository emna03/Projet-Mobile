import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/quizzes/models/ai_analysis.dart';
import 'package:studymate/features/quizzes/models/quiz.dart';
import 'package:studymate/features/quizzes/models/quiz_attempt.dart';
import 'package:studymate/features/quizzes/services/difficulty_adapter.dart';

QuizAttempt _attempt({
  required int percent,
  QuizDifficulty difficulty = QuizDifficulty.moyen,
  String subject = 'Java',
}) {
  final total = 10;
  final correct = (percent / 10).round().clamp(0, 10);
  return QuizAttempt(
    id: 'a-$percent',
    userId: 'u',
    quizId: 'q',
    quizTitle: 'T',
    subject: subject,
    difficulty: difficulty,
    correctCount: correct,
    totalCount: total,
    selectedAnswers: const [],
    completedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  const adapter = DifficultyAdapter();

  test('score élevé monte la difficulté', () {
    expect(
      adapter.fromScore(current: QuizDifficulty.facile, scorePercent: 90),
      QuizDifficulty.moyen,
    );
    expect(
      adapter.fromScore(current: QuizDifficulty.moyen, scorePercent: 85),
      QuizDifficulty.difficile,
    );
  });

  test('score bas baisse la difficulté', () {
    expect(
      adapter.fromScore(current: QuizDifficulty.difficile, scorePercent: 40),
      QuizDifficulty.moyen,
    );
    expect(
      adapter.fromScore(current: QuizDifficulty.moyen, scorePercent: 30),
      QuizDifficulty.facile,
    );
  });

  test('historique moyen adapte selon la moyenne', () {
    final attempts = [
      _attempt(percent: 90, difficulty: QuizDifficulty.facile),
      _attempt(percent: 80, difficulty: QuizDifficulty.facile),
    ];
    expect(
      adapter.fromHistory(attempts: attempts),
      QuizDifficulty.moyen,
    );
  });

  test('resolve privilégie la suggestion IA plus prudente', () {
    final analysis = AiAnalysis(
      personalizedExplanation: 'x',
      topicsToReview: const ['a'],
      revisionTips: const ['1', '2', '3'],
      nextDifficulty: 'facile',
    );
    // Score 90 → local monterait à moyen, IA dit facile → on garde facile.
    expect(
      adapter.resolve(
        current: QuizDifficulty.facile,
        scorePercent: 90,
        analysis: analysis,
      ),
      QuizDifficulty.facile,
    );
  });
}
