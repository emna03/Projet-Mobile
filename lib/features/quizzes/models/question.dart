class Question {
  const Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
  });

  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;

  Question copyWith({
    String? id,
    String? text,
    List<String>? options,
    int? correctIndex,
  }) {
    return Question(
      id: id ?? this.id,
      text: text ?? this.text,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
    );
  }
}
