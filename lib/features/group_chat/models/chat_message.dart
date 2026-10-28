/// Types of messages that can appear in a group chat.
enum MessageType {
  text,
  attachment,
  poll,
}

/// Domain model for a single chat message.
class ChatMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final int senderAvatarColorIndex;
  final MessageType messageType;
  final String content;
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final List<MessageReaction> reactions;
  final ChatAttachment? attachment;

  bool get isDeleted => deletedAt != null;
  bool get isEdited => updatedAt != null && deletedAt == null;

  const ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.senderAvatarColorIndex,
    required this.messageType,
    required this.content,
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderName,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.reactions = const [],
    this.attachment,
  });

  ChatMessage copyWith({
    String? content,
    DateTime? updatedAt,
    DateTime? deletedAt,
    List<MessageReaction>? reactions,
    ChatAttachment? attachment,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
  }) {
    return ChatMessage(
      id: id,
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      senderAvatarColorIndex: senderAvatarColorIndex,
      messageType: messageType,
      content: content ?? this.content,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      reactions: reactions ?? this.reactions,
      attachment: attachment ?? this.attachment,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A single emoji reaction on a message.
class MessageReaction {
  final String messageId;
  final String userId;
  final String userName;
  final String emoji;
  final DateTime createdAt;

  const MessageReaction({
    required this.messageId,
    required this.userId,
    required this.userName,
    required this.emoji,
    required this.createdAt,
  });
}

/// A file attachment linked to a message.
class ChatAttachment {
  final String id;
  final String messageId;
  final String originalFilename;
  final String localPath;
  final String mimeType;
  final int fileSize;
  final DateTime createdAt;

  const ChatAttachment({
    required this.id,
    required this.messageId,
    required this.originalFilename,
    required this.localPath,
    required this.mimeType,
    required this.fileSize,
    required this.createdAt,
  });

  /// Human-readable file size string.
  String get fileSizeLabel {
    if (fileSize < 1024) return '$fileSize o';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} Ko';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  /// Whether this attachment is an image.
  bool get isImage =>
      mimeType.startsWith('image/') ||
      originalFilename.toLowerCase().endsWith('.jpg') ||
      originalFilename.toLowerCase().endsWith('.jpeg') ||
      originalFilename.toLowerCase().endsWith('.png');

  /// File extension (uppercase, without dot).
  String get extension {
    final dot = originalFilename.lastIndexOf('.');
    if (dot == -1) return 'FILE';
    return originalFilename.substring(dot + 1).toUpperCase();
  }
}
