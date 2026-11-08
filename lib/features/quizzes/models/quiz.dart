import 'question.dart';

enum QuizDifficulty { facile, moyen, difficile }

extension QuizDifficultyLabel on QuizDifficulty {
  String get label => switch (this) {
        QuizDifficulty.facile => 'Facile',
        QuizDifficulty.moyen => 'Moyen',
        QuizDifficulty.difficile => 'Difficile',
      };
}

class Quiz {
  const Quiz({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.questions,
    this.generatedByAi = false,
  });

  final String id;
  final String title;
  final String description;
  final String subject;
  final QuizDifficulty difficulty;
  final int estimatedMinutes;
  final List<Question> questions;
  final bool generatedByAi;

  int get questionCount => questions.length;

  Quiz copyWith({
    String? id,
    String? title,
    String? description,
    String? subject,
    QuizDifficulty? difficulty,
    int? estimatedMinutes,
    List<Question>? questions,
    bool? generatedByAi,
  }) {
    return Quiz(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      difficulty: difficulty ?? this.difficulty,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      questions: questions ?? this.questions,
      generatedByAi: generatedByAi ?? this.generatedByAi,
    );
  }
}
