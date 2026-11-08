import '../../gestion_user/models/public_profile.dart';
import '../models/group.dart';
import '../models/join_request.dart';

/// Contrat d'accès aux données des groupes.
///
/// L'interface reprend celle du module d'origine (SQLite) pour que le
/// `GroupViewModel` et les vues restent inchangés. L'implémentation de
/// production est `FirestoreGroupRepository` (données partagées entre
/// appareils) ; les tests utilisent un dépôt en mémoire.
///
/// Les méthodes d'écriture renvoient `null` en cas de succès ou un message
/// d'erreur en français, comme dans le module d'origine.
abstract class GroupRepository {
  // ─── Utilisateurs (profils publics) ────────────────────────────────────────
  Future<List<PublicProfile>> getAllUsers();
  Future<PublicProfile?> getUserById(String id);
  Future<List<PublicProfile>> getMembersOfGroup(String groupId);

  // ─── Groupes ───────────────────────────────────────────────────────────────
  Future<List<Group>> getGroups();
  Future<Group?> getGroupById(String id);
  Future<Group> addGroup(Group group);
  Future<Group> updateGroup(Group group);
  Future<bool> deleteGroup(String id);

  // ─── Adhésion ──────────────────────────────────────────────────────────────
  Future<bool> isMember(String groupId, String userId);
  Future<String?> joinGroup(String groupId, String userId);
  Future<String?> leaveGroup(String groupId, String userId);
  Future<String?> removeMember(String groupId, String userId);

  // ─── Demandes d'adhésion ───────────────────────────────────────────────────
  Future<String?> sendJoinRequest(String groupId, String userId);
  Future<bool> cancelJoinRequest(String groupId, String userId);
  Future<List<JoinRequest>> getPendingRequests(String groupId);
  Future<JoinRequest?> getPendingRequest(String groupId, String userId);
  Future<List<JoinRequest>> getPendingRequestsForUser(String userId);
  Future<String?> acceptJoinRequest(String requestId, String groupId, String userId);
  Future<bool> rejectJoinRequest(String requestId);

  /// Flux émis à chaque changement distant (groupes, demandes) pour
  /// [userId]. `null` = pas de temps réel (ex. dépôt de test).
  Stream<void>? watchChanges(String userId);
}
