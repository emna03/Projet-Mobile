class KnowledgeEdge {
  const KnowledgeEdge({
    required this.id,
    required this.fromConceptId,
    required this.toConceptId,
    required this.relationType,
    this.weight = 1.0,
    this.justification = '',
  });

  /// Types supportés : prerequisite, related, part_of
  final String id;
  final String fromConceptId;
  final String toConceptId;
  final String relationType;
  final double weight;
  final String justification;

  Map<String, dynamic> toMap() => {
        'id': id,
        'from_concept_id': fromConceptId,
        'to_concept_id': toConceptId,
        'relation_type': relationType,
        'weight': weight,
        'justification': justification,
      };

  factory KnowledgeEdge.fromMap(Map<String, dynamic> map) {
    return KnowledgeEdge(
      id: map['id']?.toString() ?? '',
      fromConceptId: map['from_concept_id']?.toString() ?? '',
      toConceptId: map['to_concept_id']?.toString() ?? '',
      relationType: map['relation_type']?.toString() ?? 'related',
      weight: double.tryParse(map['weight']?.toString() ?? '') ?? 1.0,
      justification: map['justification']?.toString() ?? '',
    );
  }
}
