import 'quiz.dart';

class QuizResult {
  const QuizResult({
    required this.quizId,
    required this.quizTitle,
    required this.subject,
    required this.difficulty,
    required this.dateLabel,
    required this.correctCount,
    required this.totalCount,
  });

  final String quizId;
  final String quizTitle;
  final String subject;
  final QuizDifficulty difficulty;
  final String dateLabel;
  final int correctCount;
  final int totalCount;

  int get wrongCount => totalCount - correctCount;

  int get scorePercent =>
      totalCount == 0 ? 0 : ((correctCount / totalCount) * 100).round();
}
