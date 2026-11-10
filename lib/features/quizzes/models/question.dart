import 'quiz.dart';

class Question {
  const Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
    this.difficulty = QuizDifficulty.moyen,
  });

  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final QuizDifficulty difficulty;

  Question copyWith({
    String? id,
    String? text,
    List<String>? options,
    int? correctIndex,
    String? explanation,
    QuizDifficulty? difficulty,
  }) {
    return Question(
      id: id ?? this.id,
      text: text ?? this.text,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      explanation: explanation ?? this.explanation,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
        'difficulty': difficulty.name,
      };

  factory Question.fromJson(Map<String, dynamic> json, {String? fallbackId}) {
    final options = (json['options'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    final correct = json['correctIndex'];
    final correctIndex = correct is int
        ? correct
        : int.tryParse(correct?.toString() ?? '') ?? 0;
    return Question(
      id: (json['id']?.toString().isNotEmpty ?? false)
          ? json['id'].toString()
          : (fallbackId ?? 'q-${DateTime.now().microsecondsSinceEpoch}'),
      text: json['text']?.toString() ?? json['question']?.toString() ?? '',
      options: options,
      correctIndex: correctIndex.clamp(0, options.isEmpty ? 0 : options.length - 1),
      explanation: json['explanation']?.toString() ?? '',
      difficulty: quizDifficultyFromName(json['difficulty']?.toString()),
    );
  }
}

QuizDifficulty quizDifficultyFromName(String? raw) {
  final value = (raw ?? '').trim().toLowerCase();
  return switch (value) {
    'facile' || 'easy' => QuizDifficulty.facile,
    'difficile' || 'hard' => QuizDifficulty.difficile,
    _ => QuizDifficulty.moyen,
  };
}
