import '../../users/models/user.dart';

/// Membership status of the current user with respect to a group.
enum MembershipStatus {
  /// User is the owner of the group.
  owner,

  /// User is a regular member.
  member,

  /// User has a pending join request (private groups).
  requested,

  /// User is not a member and has no pending request.
  none,

  /// Group is at full capacity.
  full,
}

/// Group domain model.
///
/// Members are eager-loaded for display purposes. For write operations use
/// the repository methods which operate directly on SQLite.
class Group {
  final String id;
  final String name;
  final String description;
  final String level;
  final bool isPublic;
  final int maxMembers;
  final String ownerId;
  final List<User> members;
  final DateTime createdAt;

  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.level,
    this.isPublic = true,
    this.maxMembers = 10,
    required this.ownerId,
    this.members = const [],
    required this.createdAt,
  });

  /// Number of rows in `group_members` for this group.
  ///
  /// The owner is persisted as a regular membership row (seed data and
  /// `GroupViewModel.createGroup` both insert it), and the table's
  /// `PRIMARY KEY (group_id, user_id)` guarantees uniqueness, so the owner is
  /// counted exactly once.
  int get memberCount => members.length;
  bool get isFull => members.length >= maxMembers;

  User? get owner {
    try {
      return members.firstWhere((m) => m.id == ownerId);
    } catch (_) {
      return null;
    }
  }

  /// Returns copy of Group with updated properties.
  Group copyWith({
    String? id,
    String? name,
    String? description,
    String? level,
    bool? isPublic,
    int? maxMembers,
    String? ownerId,
    List<User>? members,
    DateTime? createdAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      level: level ?? this.level,
      isPublic: isPublic ?? this.isPublic,
      maxMembers: maxMembers ?? this.maxMembers,
      ownerId: ownerId ?? this.ownerId,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Group && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
