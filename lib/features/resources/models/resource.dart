import 'dart:typed_data';

import '../../../core/constants/session_user.dart';

enum ResourceVisibility { public, private, group }

enum ResourcePricing { free, paid }

enum ResourceFileKind {
  pdf,
  powerpoint,
  other;

  String get label => switch (this) {
        pdf => 'PDF',
        powerpoint => 'PowerPoint',
        other => 'Fichier',
      };

  String mimeTypeFor(String? name) {
    final lower = (name ?? '').toLowerCase();
    return switch (this) {
      pdf => 'application/pdf',
      powerpoint when lower.endsWith('.ppt') => 'application/vnd.ms-powerpoint',
      powerpoint =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      other => 'application/octet-stream',
    };
  }

  static ResourceFileKind fromName(String? name) {
    final lower = (name ?? '').toLowerCase();
    if (lower.endsWith('.pdf')) return pdf;
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return powerpoint;
    return other;
  }
}

class Resource {
  final int? id;
  final String title;
  final String subject;
  final String author;
  final String ownerName;
  final String content;
  final ResourceVisibility visibility;
  final String? groupId;
  final String? groupName;
  final bool isFree;
  final double price;
  final int pages;
  final String? summary;
  final String? pdfPath;
  final String? pdfName;
  final Uint8List? pdfBytes;
  final int createdAt;
  final bool isFavorite;

  const Resource({
    this.id,
    required this.title,
    required this.subject,
    required this.author,
    required this.ownerName,
    required this.content,
    required this.visibility,
    this.groupId,
    this.groupName,
    required this.isFree,
    this.price = 0,
    required this.pages,
    this.summary,
    this.pdfPath,
    this.pdfName,
    this.pdfBytes,
    required this.createdAt,
    this.isFavorite = false,
  });

  bool get hasFile => pdfName != null && pdfName!.isNotEmpty;

  bool get canOpenFile =>
      (pdfBytes != null && pdfBytes!.isNotEmpty) ||
      (pdfPath != null && pdfPath!.isNotEmpty);

  bool get hasPdf => hasFile && attachedKind == ResourceFileKind.pdf;

  ResourceFileKind get attachedKind => ResourceFileKind.fromName(pdfName ?? pdfPath);

  String get attachedLabel => attachedKind.label;

  String get attachedMimeType => attachedKind.mimeTypeFor(pdfName ?? pdfPath);

  ResourcePricing get pricing => isFree ? ResourcePricing.free : ResourcePricing.paid;

  String get visibilityLabel => switch (visibility) {
        ResourceVisibility.public => 'Public',
        ResourceVisibility.private => 'Privé',
        ResourceVisibility.group => groupName == null ? 'Groupe' : 'Groupe · $groupName',
      };

  String get priceLabel => isFree ? 'Gratuit' : 'Payant · ${price.toStringAsFixed(0)} DT';

  bool get isOwnedByMe => ownerName == SessionUser.email;

  bool get canManage => SessionUser.isTeacher && isOwnedByMe;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'subject': subject,
        'author': author,
        'owner_name': ownerName,
        'content': content,
        'visibility': visibility.name,
        'group_id': groupId,
        'group_name': groupName,
        'is_free': isFree ? 1 : 0,
        'price': price,
        'pages': pages,
        'summary': summary,
        'pdf_path': pdfPath,
        'pdf_name': pdfName,
        'pdf_bytes': pdfBytes,
        'created_at': createdAt,
        'is_favorite': isFavorite ? 1 : 0,
      };

  factory Resource.fromMap(Map<String, Object?> map) => Resource(
        id: map['id'] as int?,
        title: map['title'] as String,
        subject: map['subject'] as String,
        author: map['author'] as String,
        ownerName: map['owner_name'] as String,
        content: map['content'] as String,
        visibility: ResourceVisibility.values.byName(map['visibility'] as String),
        groupId: map['group_id'] as String?,
        groupName: map['group_name'] as String?,
        isFree: (map['is_free'] as int) == 1,
        price: (map['price'] as num).toDouble(),
        pages: map['pages'] as int,
        summary: map['summary'] as String?,
        pdfPath: map['pdf_path'] as String?,
        pdfName: map['pdf_name'] as String?,
        pdfBytes: map['pdf_bytes'] is Uint8List ? map['pdf_bytes'] as Uint8List : null,
        createdAt: map['created_at'] as int,
        isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      );

  Resource copyWith({
    int? id,
    String? title,
    String? subject,
    String? author,
    String? ownerName,
    String? content,
    ResourceVisibility? visibility,
    String? groupId,
    String? groupName,
    bool? isFree,
    double? price,
    int? pages,
    String? summary,
    String? pdfPath,
    String? pdfName,
    Uint8List? pdfBytes,
    int? createdAt,
    bool? isFavorite,
    bool clearGroup = false,
    bool clearPdf = false,
  }) =>
      Resource(
        id: id ?? this.id,
        title: title ?? this.title,
        subject: subject ?? this.subject,
        author: author ?? this.author,
        ownerName: ownerName ?? this.ownerName,
        content: content ?? this.content,
        visibility: visibility ?? this.visibility,
        groupId: clearGroup ? null : (groupId ?? this.groupId),
        groupName: clearGroup ? null : (groupName ?? this.groupName),
        isFree: isFree ?? this.isFree,
        price: price ?? this.price,
        pages: pages ?? this.pages,
        summary: summary ?? this.summary,
        pdfPath: clearPdf ? null : (pdfPath ?? this.pdfPath),
        pdfName: clearPdf ? null : (pdfName ?? this.pdfName),
        pdfBytes: clearPdf ? null : (pdfBytes ?? this.pdfBytes),
        createdAt: createdAt ?? this.createdAt,
        isFavorite: isFavorite ?? this.isFavorite,
      );
}

class Flashcard {
  final int? id;
  final int resourceId;
  final String question;
  final String answer;

  const Flashcard({
    this.id,
    required this.resourceId,
    required this.question,
    required this.answer,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'resource_id': resourceId,
        'question': question,
        'answer': answer,
      };

  factory Flashcard.fromMap(Map<String, Object?> map) => Flashcard(
        id: map['id'] as int?,
        resourceId: map['resource_id'] as int,
        question: map['question'] as String,
        answer: map['answer'] as String,
      );
}
