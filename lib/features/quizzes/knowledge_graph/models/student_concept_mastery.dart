import 'mastery_level.dart';

class StudentConceptMastery {
  const StudentConceptMastery({
    required this.id,
    required this.userId,
    required this.conceptId,
    required this.scorePercent,
    required this.level,
    required this.correctWeight,
    required this.totalWeight,
    required this.attemptCount,
    required this.distinctQuestions,
    this.lastAttemptAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String conceptId;
  final double scorePercent;
  final MasteryLevel level;
  final double correctWeight;
  final double totalWeight;
  final int attemptCount;
  final int distinctQuestions;
  final DateTime? lastAttemptAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'concept_id': conceptId,
        'score_percent': scorePercent,
        'level': level.name,
        'correct_weight': correctWeight,
        'total_weight': totalWeight,
        'attempt_count': attemptCount,
        'distinct_questions': distinctQuestions,
        'last_attempt_at': lastAttemptAt?.toIso8601String(),
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  factory StudentConceptMastery.fromMap(Map<String, dynamic> map) {
    return StudentConceptMastery(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      conceptId: map['concept_id']?.toString() ?? '',
      scorePercent: double.tryParse(map['score_percent']?.toString() ?? '') ?? 0,
      level: masteryLevelFromName(map['level']?.toString()),
      correctWeight:
          double.tryParse(map['correct_weight']?.toString() ?? '') ?? 0,
      totalWeight: double.tryParse(map['total_weight']?.toString() ?? '') ?? 0,
      attemptCount: int.tryParse(map['attempt_count']?.toString() ?? '') ?? 0,
      distinctQuestions:
          int.tryParse(map['distinct_questions']?.toString() ?? '') ?? 0,
      lastAttemptAt: DateTime.tryParse(map['last_attempt_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }
}
