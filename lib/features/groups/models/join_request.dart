/// Status values for a join request.
enum JoinRequestStatus { pending, accepted, rejected }

/// Domain model for a group join request.
class JoinRequest {
  final String id;
  final String groupId;
  final String userId;
  final JoinRequestStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  /// Optional: name of the requesting user (eagerly loaded for display).
  final String? userName;

  const JoinRequest({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.userName,
  });

  JoinRequest copyWith({
    JoinRequestStatus? status,
    DateTime? reviewedAt,
  }) {
    return JoinRequest(
      id: id,
      groupId: groupId,
      userId: userId,
      status: status ?? this.status,
      createdAt: createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      userName: userName,
    );
  }
}
