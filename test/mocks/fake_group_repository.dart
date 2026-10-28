import 'package:studymate/features/groups/models/group.dart';
import 'package:studymate/features/groups/models/join_request.dart';
import 'package:studymate/features/groups/repositories/group_repository.dart';
import 'package:studymate/features/users/models/user.dart';

/// In-memory fake repository for lightning-fast, hermetic unit tests.
class FakeGroupRepository implements GroupRepository {
  final List<User> _users = [
    const User(id: 'u0', name: 'Ilyes Étudiant', email: 'ilyes@studymate.tn', role: 'Étudiant', avatarColorIndex: 0),
    const User(id: 'u1', name: 'Sarah Ben Ali', email: 'sarah@example.com', role: 'Déléguée', avatarColorIndex: 1),
    const User(id: 'u2', name: 'Yassine Trabelsi', email: 'yassine@example.com', role: 'Étudiant', avatarColorIndex: 2),
    const User(id: 'u3', name: 'Ines Haddad', email: 'ines@example.com', role: 'Étudiante', avatarColorIndex: 3),
  ];

  late final List<Group> _groups;
  final List<JoinRequest> _requests = [];

  FakeGroupRepository({List<Group>? initialGroups}) {
    _groups = initialGroups ??
        [
          Group(
            id: 'g1',
            name: 'Spring Boot Masters',
            description: 'Groupe d\'entraide Spring Boot',
            level: 'Licence 3',
            isPublic: true,
            maxMembers: 10,
            ownerId: 'u1',
            members: [_users[1], _users[2]],
            createdAt: DateTime.now(),
          ),
          Group(
            id: 'g2',
            name: 'Docker & DevOps',
            description: 'Apprentissage conteneurs',
            level: 'Master 1',
            isPublic: false,
            maxMembers: 5,
            ownerId: 'u0', // Current user owns this
            members: [_users[0], _users[3]],
            createdAt: DateTime.now(),
          ),
        ];
  }

  @override
  Future<List<User>> getAllUsers() async => List.unmodifiable(_users);

  @override
  Future<User?> getUserById(String id) async {
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<User>> getMembersOfGroup(String groupId) async {
    final g = await getGroupById(groupId);
    return g?.members ?? [];
  }

  @override
  Future<List<Group>> getGroups() async => List.unmodifiable(_groups);

  @override
  Future<Group?> getGroupById(String id) async {
    try {
      return _groups.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Group> addGroup(Group group) async {
    _groups.insert(0, group);
    return group;
  }

  @override
  Future<Group> updateGroup(Group group) async {
    final index = _groups.indexWhere((g) => g.id == group.id);
    if (index != -1) {
      _groups[index] = group;
      return group;
    }
    throw Exception('Group not found');
  }

  @override
  Future<bool> deleteGroup(String id) async {
    final count = _groups.length;
    _groups.removeWhere((g) => g.id == id);
    _requests.removeWhere((r) => r.groupId == id);
    return _groups.length < count;
  }

  @override
  Future<bool> isMember(String groupId, String userId) async {
    final g = await getGroupById(groupId);
    return g?.members.any((m) => m.id == userId) ?? false;
  }

  @override
  Future<String?> joinGroup(String groupId, String userId) async {
    final g = await getGroupById(groupId);
    if (g == null) return 'Groupe introuvable.';
    if (g.members.any((m) => m.id == userId)) return 'Vous êtes déjà membre du groupe.';
    if (g.isFull) return 'Le groupe est complet.';

    final user = await getUserById(userId);
    if (user == null) return 'Utilisateur introuvable.';

    final updated = g.copyWith(members: [...g.members, user]);
    await updateGroup(updated);
    return null;
  }

  @override
  Future<String?> leaveGroup(String groupId, String userId) async {
    final g = await getGroupById(groupId);
    if (g == null) return 'Groupe introuvable.';
    if (g.ownerId == userId) return 'Le créateur ne peut pas quitter son propre groupe.';

    final updated = g.copyWith(members: g.members.where((m) => m.id != userId).toList());
    await updateGroup(updated);
    return null;
  }

  @override
  Future<String?> sendJoinRequest(String groupId, String userId) async {
    final g = await getGroupById(groupId);
    if (g == null) return 'Groupe introuvable.';
    if (g.members.any((m) => m.id == userId)) return 'Vous êtes déjà membre du groupe.';
    if (_requests.any((r) => r.groupId == groupId && r.userId == userId && r.status == JoinRequestStatus.pending)) {
      return 'Une demande est déjà en attente.';
    }

    _requests.add(JoinRequest(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      groupId: groupId,
      userId: userId,
      status: JoinRequestStatus.pending,
      createdAt: DateTime.now(),
      userName: (await getUserById(userId))?.name,
    ));
    return null;
  }

  @override
  Future<bool> cancelJoinRequest(String groupId, String userId) async {
    final count = _requests.length;
    _requests.removeWhere((r) => r.groupId == groupId && r.userId == userId && r.status == JoinRequestStatus.pending);
    return _requests.length < count;
  }

  @override
  Future<List<JoinRequest>> getPendingRequests(String groupId) async {
    return _requests.where((r) => r.groupId == groupId && r.status == JoinRequestStatus.pending).toList();
  }

  @override
  Future<JoinRequest?> getPendingRequest(String groupId, String userId) async {
    try {
      return _requests.firstWhere((r) => r.groupId == groupId && r.userId == userId && r.status == JoinRequestStatus.pending);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<JoinRequest>> getPendingRequestsForUser(String userId) async {
    return _requests
        .where((r) => r.userId == userId && r.status == JoinRequestStatus.pending)
        .toList();
  }

  @override
  Future<String?> acceptJoinRequest(String requestId, String groupId, String userId) async {
    final g = await getGroupById(groupId);
    if (g == null) return 'Groupe introuvable.';
    if (g.isFull) return 'Le groupe est complet. Impossible d\'accepter cette demande.';

    final reqIndex = _requests.indexWhere((r) => r.id == requestId);
    if (reqIndex != -1) {
      _requests[reqIndex] = _requests[reqIndex].copyWith(
        status: JoinRequestStatus.accepted,
        reviewedAt: DateTime.now(),
      );
    }
    return joinGroup(groupId, userId);
  }

  @override
  Future<bool> rejectJoinRequest(String requestId) async {
    final reqIndex = _requests.indexWhere((r) => r.id == requestId);
    if (reqIndex != -1) {
      _requests[reqIndex] = _requests[reqIndex].copyWith(
        status: JoinRequestStatus.rejected,
        reviewedAt: DateTime.now(),
      );
      return true;
    }
    return false;
  }

  @override
  Future<String?> removeMember(String groupId, String userId) async {
    final g = await getGroupById(groupId);
    if (g == null) return 'Groupe introuvable.';
    if (g.ownerId == userId) return 'Le créateur du groupe ne peut pas être retiré.';

    final updated = g.copyWith(members: g.members.where((m) => m.id != userId).toList());
    await updateGroup(updated);
    return null;
  }
}
