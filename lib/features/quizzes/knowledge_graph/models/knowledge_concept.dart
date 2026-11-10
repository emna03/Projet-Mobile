class KnowledgeConcept {
  const KnowledgeConcept({
    required this.id,
    required this.canonicalName,
    required this.displayName,
    this.subject = '',
    this.description = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String canonicalName;
  final String displayName;
  final String subject;
  final String description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'canonical_name': canonicalName,
        'display_name': displayName,
        'subject': subject,
        'description': description,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  factory KnowledgeConcept.fromMap(Map<String, dynamic> map) {
    return KnowledgeConcept(
      id: map['id']?.toString() ?? '',
      canonicalName: map['canonical_name']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }
}
