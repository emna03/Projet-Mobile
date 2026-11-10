import 'mastery_level.dart';

class KnowledgeRecommendation {
  const KnowledgeRecommendation({
    required this.conceptId,
    required this.conceptName,
    required this.priority,
    required this.reason,
    required this.currentLevel,
    required this.targetLevel,
    this.relatedQuizIds = const [],
    this.dependentOn = const [],
  });

  final String conceptId;
  final String conceptName;
  final int priority;
  final String reason;
  final MasteryLevel currentLevel;
  final MasteryLevel targetLevel;
  final List<String> relatedQuizIds;
  final List<String> dependentOn;
}
