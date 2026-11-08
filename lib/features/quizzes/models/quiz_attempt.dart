import 'quiz.dart';

/// Tentative de quiz persistée, associée à un utilisateur (Firebase UID si dispo).
class QuizAttempt {
  const QuizAttempt({
    required this.id,
    required this.userId,
    required this.quizId,
    required this.quizTitle,
    required this.subject,
    required this.difficulty,
    required this.correctCount,
    required this.totalCount,
    required this.selectedAnswers,
    required this.completedAt,
    this.source = 'local',
    this.aiAnalysisJson,
  });

  final String id;
  final String userId;
  final String quizId;
  final String quizTitle;
  final String subject;
  final QuizDifficulty difficulty;
  final int correctCount;
  final int totalCount;
  final List<int?> selectedAnswers;
  final DateTime completedAt;
  final String source;
  final String? aiAnalysisJson;

  int get wrongCount => totalCount - correctCount;

  int get scorePercent =>
      totalCount == 0 ? 0 : ((correctCount / totalCount) * 100).round();

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'quiz_id': quizId,
        'quiz_title': quizTitle,
        'subject': subject,
        'difficulty': difficulty.name,
        'correct_count': correctCount,
        'total_count': totalCount,
        'selected_answers': selectedAnswers.map((e) => e?.toString() ?? '').join(','),
        'completed_at': completedAt.toIso8601String(),
        'source': source,
        'ai_analysis_json': aiAnalysisJson,
      };

  factory QuizAttempt.fromMap(Map<String, dynamic> map) {
    final rawAnswers = (map['selected_answers']?.toString() ?? '').split(',');
    return QuizAttempt(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? 'local-demo',
      quizId: map['quiz_id']?.toString() ?? '',
      quizTitle: map['quiz_title']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      difficulty: QuizDifficulty.values.firstWhere(
        (d) => d.name == map['difficulty']?.toString(),
        orElse: () => QuizDifficulty.moyen,
      ),
      correctCount: int.tryParse(map['correct_count']?.toString() ?? '') ?? 0,
      totalCount: int.tryParse(map['total_count']?.toString() ?? '') ?? 0,
      selectedAnswers: [
        for (final item in rawAnswers)
          item.isEmpty ? null : int.tryParse(item),
      ],
      completedAt: DateTime.tryParse(map['completed_at']?.toString() ?? '') ??
          DateTime.now(),
      source: map['source']?.toString() ?? 'local',
      aiAnalysisJson: map['ai_analysis_json']?.toString(),
    );
  }
}
