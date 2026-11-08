class QuestionConceptLink {
  const QuestionConceptLink({
    required this.id,
    required this.questionId,
    required this.quizId,
    required this.conceptId,
    this.weight = 1.0,
    this.skillLabel = '',
  });

  final String id;
  final String questionId;
  final String quizId;
  final String conceptId;
  final double weight;
  final String skillLabel;

  Map<String, dynamic> toMap() => {
        'id': id,
        'question_id': questionId,
        'quiz_id': quizId,
        'concept_id': conceptId,
        'weight': weight,
        'skill_label': skillLabel,
      };

  factory QuestionConceptLink.fromMap(Map<String, dynamic> map) {
    return QuestionConceptLink(
      id: map['id']?.toString() ?? '',
      questionId: map['question_id']?.toString() ?? '',
      quizId: map['quiz_id']?.toString() ?? '',
      conceptId: map['concept_id']?.toString() ?? '',
      weight: double.tryParse(map['weight']?.toString() ?? '') ?? 1.0,
      skillLabel: map['skill_label']?.toString() ?? '',
    );
  }
}
