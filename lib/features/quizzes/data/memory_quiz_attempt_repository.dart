import '../models/quiz_attempt.dart';
import 'quiz_attempt_repository.dart';

/// Variante 100 % mémoire pour la démo / tests widget (pas de SQLite).
class MemoryQuizAttemptRepository extends QuizAttemptRepository {
  MemoryQuizAttemptRepository() : super(database: null);

  final List<QuizAttempt> _items = [];

  @override
  Future<void> save(QuizAttempt attempt) async {
    _items.removeWhere((e) => e.id == attempt.id);
    _items.insert(0, attempt);
  }

  @override
  Future<List<QuizAttempt>> listForUser(String userId) async {
    return _items.where((e) => e.userId == userId).toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }

  @override
  Future<List<QuizAttempt>> listForQuiz({
    required String userId,
    required String quizId,
  }) async {
    return _items
        .where((e) => e.userId == userId && e.quizId == quizId)
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }

  @override
  Future<void> updateAnalysis({
    required String attemptId,
    required String analysisJson,
  }) async {
    final index = _items.indexWhere((e) => e.id == attemptId);
    if (index < 0) return;
    final current = _items[index];
    _items[index] = QuizAttempt(
      id: current.id,
      userId: current.userId,
      quizId: current.quizId,
      quizTitle: current.quizTitle,
      subject: current.subject,
      difficulty: current.difficulty,
      correctCount: current.correctCount,
      totalCount: current.totalCount,
      selectedAnswers: current.selectedAnswers,
      completedAt: current.completedAt,
      source: current.source,
      aiAnalysisJson: analysisJson,
    );
  }
}
