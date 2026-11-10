import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/session_user.dart';
import '../../../core/services/group_membership.dart';
import '../../../core/utils/validators.dart';
import '../../gestion_user/models/public_profile.dart';
import '../models/group.dart';
import '../models/group_filters.dart';
import '../models/join_request.dart';
import '../repositories/group_repository.dart';

/// ViewModel managing state and UI interaction for all group-related screens.
///
/// Uses [ChangeNotifier] + [ListenableBuilder] as in the original app.
/// All data access goes through [GroupRepository] (Firestore in production).
///
/// L'utilisateur courant est l'utilisateur Firebase connecté
/// ([SessionUser.uid]) ; [sessionChanges] (ex. `authStateChanges()`) permet
/// de recharger l'état quand le compte change (connexion / déconnexion).
class GroupViewModel extends ChangeNotifier implements GroupMembershipSource {
  GroupViewModel({
    required GroupRepository repository,
    String Function()? currentUserIdProvider,
    Stream<Object?>? sessionChanges,
  })  : _repo = repository,
        _currentUserId = currentUserIdProvider ?? (() => SessionUser.uid) {
    _sessionSub = sessionChanges?.listen((_) => _onSessionChanged());
    loadData();
  }

  final GroupRepository _repo;
  final String Function() _currentUserId;
  StreamSubscription<Object?>? _sessionSub;
  StreamSubscription<void>? _changesSub;
  String _watchedUserId = '';
  bool _disposed = false;

  // ─── State ─────────────────────────────────────────────────────────────────

  List<Group> _groups = [];
  List<PublicProfile> _allUsers = [];
  Map<String, List<JoinRequest>> _pendingRequests = {};
  Set<String> _userPendingGroupIds = {};

  bool _isLoading = false;
  String? _errorMessage;

  /// Raw text typed in the search field (updated on every keystroke).
  String _searchInput = '';

  /// Debounced query actually applied to the list.
  String _searchQuery = '';
  Timer? _searchDebounce;
  static const searchDebounceDuration = Duration(milliseconds: 300);

  GroupFilters _filters = GroupFilters.none;

  // ─── Getters ───────────────────────────────────────────────────────────────

  List<Group> get groups => _groups;
  List<PublicProfile> get allUsers => _allUsers;
  bool get isLoading => _isLoading;
  String get searchInput => _searchInput;
  String get searchQuery => _searchQuery;
  GroupFilters get filters => _filters;
  String get selectedLevel => _filters.level ?? 'Tous';
  String? get errorMessage => _errorMessage;
  String get currentUserId => _currentUserId();

  bool get isSignedIn => currentUserId.isNotEmpty;

  bool isOwnerOf(String groupId) =>
      getGroupById(groupId)?.ownerId == currentUserId && isSignedIn;

  // ─── GroupMembershipSource (module Ressources) ─────────────────────────────

  @override
  List<GroupRef> get memberGroups => [
        for (final g in _groups)
          if (g.members.any((m) => m.id == currentUserId) || g.ownerId == currentUserId)
            GroupRef(g.id, g.name),
      ];

  @override
  Set<String> get memberGroupIds => memberGroups.map((g) => g.id).toSet();

  bool isMemberOf(String groupId) => memberGroupIds.contains(groupId);

  /// `true` when either a search query or an advanced filter is active.
  bool get hasActiveCriteria =>
      _searchQuery.isNotEmpty || _filters.hasActiveFilters;

  /// Groups matching the search query AND every active filter.
  List<Group> get filteredGroups {
    final query = _searchQuery.trim().toLowerCase();
    return _groups.where((g) {
      final matchesSearch = query.isEmpty ||
          g.name.toLowerCase().contains(query) ||
          g.description.toLowerCase().contains(query);

      return matchesSearch && _filters.matches(g);
    }).toList();
  }

  /// Returns the membership status of the current user for a given group.
  MembershipStatus membershipStatus(Group group) {
    final uid = currentUserId;
    if (group.ownerId == uid) return MembershipStatus.owner;
    if (group.members.any((m) => m.id == uid)) return MembershipStatus.member;
    if (_userPendingGroupIds.contains(group.id) ||
        (_pendingRequests[group.id]?.any((r) => r.userId == uid) ?? false)) {
      return MembershipStatus.requested;
    }
    if (group.isFull) return MembershipStatus.full;
    return MembershipStatus.none;
  }

  /// Returns pending join requests for a group the current user owns.
  List<JoinRequest> pendingRequestsFor(String groupId) =>
      _pendingRequests[groupId] ?? [];

  // ─── Initialisation ────────────────────────────────────────────────────────

  /// Charge groupes, profils et demandes de l'utilisateur connecté.
  ///
  /// [silent] : rafraîchissement en arrière-plan (temps réel), sans
  /// indicateur de chargement.
  Future<void> loadData({bool silent = false}) async {
    final uid = currentUserId;
    _ensureWatching(uid);
    if (uid.isEmpty) {
      _resetState();
      notifyListeners();
      return;
    }

    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final groups = List<Group>.from(await _repo.getGroups());
      if (_disposed || currentUserId != uid) return;
      _groups = groups;
      await _loadPendingRequests();
      // Liste complète des profils : seulement au chargement initial, pas à
      // chaque rafraîchissement temps réel (c'était la requête la plus lourde).
      if (!silent || _allUsers.isEmpty) {
        try {
          _allUsers = List<PublicProfile>.from(await _repo.getAllUsers());
        } catch (e) {
          // La liste des profils ne sert qu'à la sélection de membres :
          // son échec ne doit pas empêcher l'affichage des groupes.
          debugPrint('GroupViewModel.getAllUsers: $e');
        }
      }
      _errorMessage = null;
    } catch (e) {
      debugPrint('GroupViewModel.loadData: $e');
      if (!silent) _errorMessage = 'Erreur lors du chargement des données.';
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _resetState() {
    _groups = [];
    _allUsers = [];
    _pendingRequests = {};
    _userPendingGroupIds = {};
    _errorMessage = null;
    _isLoading = false;
    _noticesReady = false;
  }

  /// Abonnement temps réel aux changements Firestore de l'utilisateur.
  void _ensureWatching(String uid) {
    if (uid == _watchedUserId) return;
    _changesSub?.cancel();
    _changesSub = null;
    _watchedUserId = uid;
    final stream = _repo.watchChanges(uid);
    if (stream == null) return;
    _changesSub = stream.listen((_) {
      if (!_disposed && !_isLoading) loadData(silent: true);
    });
  }

  void _onSessionChanged() {
    if (_disposed || currentUserId == _watchedUserId) return;
    _resetState();
    loadData();
  }

  Future<void> _loadPendingRequests() async {
    final previousIncoming = allPendingRequests.map((r) => r.id).toSet();
    final previousMine = Set<String>.from(_userPendingGroupIds);

    final ownedGroupIds =
        _groups.where((g) => g.ownerId == currentUserId).map((g) => g.id);

    final map = <String, List<JoinRequest>>{};
    for (final gid in ownedGroupIds) {
      map[gid] = await _repo.getPendingRequests(gid);
    }
    _pendingRequests = map;

    final myRequests = await _repo.getPendingRequestsForUser(currentUserId);
    _userPendingGroupIds = myRequests.map((r) => r.groupId).toSet();

    // Pas de notification pour l'état trouvé au premier chargement : le
    // badge suffit. Ensuite, chaque changement temps réel est signalé.
    if (_noticesReady) _emitNotices(previousIncoming, previousMine);
    _noticesReady = true;
  }

  // ─── Notifications de demandes d'adhésion ──────────────────────────────────

  final StreamController<GroupNotice> _notices = StreamController<GroupNotice>.broadcast();
  bool _noticesReady = false;

  /// Événements à afficher (nouvelle demande reçue, demande acceptée/refusée).
  Stream<GroupNotice> get notices => _notices.stream;

  /// Demandes en attente sur tous les groupes dont je suis propriétaire.
  List<JoinRequest> get allPendingRequests => [
        for (final list in _pendingRequests.values) ...list,
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  int get pendingRequestCount => _pendingRequests.values.fold(0, (n, l) => n + l.length);

  String groupNameOf(String groupId) => getGroupById(groupId)?.name ?? 'Groupe';

  void _emitNotices(Set<String> previousIncoming, Set<String> previousMine) {
    if (_notices.isClosed) return;
    // Propriétaire : nouvelles demandes reçues.
    for (final r in allPendingRequests) {
      if (previousIncoming.contains(r.id)) continue;
      _notices.add(GroupNotice(
        '${r.userName ?? 'Un étudiant'} veut rejoindre « ${groupNameOf(r.groupId)} ».',
        request: r,
      ));
    }
    // Demandeur : réponse du propriétaire.
    for (final gid in previousMine.difference(_userPendingGroupIds)) {
      final group = getGroupById(gid);
      if (group == null) continue;
      final accepted = group.members.any((m) => m.id == currentUserId);
      _notices.add(GroupNotice(
        accepted
            ? 'Votre demande pour « ${group.name} » a été acceptée. Bienvenue !'
            : 'Votre demande pour « ${group.name} » a été refusée.',
      ));
    }
  }

  // ─── Filters ───────────────────────────────────────────────────────────────

  /// Records the typed text immediately and applies it to the list after
  /// [searchDebounceDuration] of inactivity.
  void setSearchQuery(String query) {
    _searchInput = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(searchDebounceDuration, () {
      _searchQuery = _searchInput;
      notifyListeners();
    });
    // Rebuild right away so the field's clear button reflects the input.
    notifyListeners();
  }

  void clearSearch() {
    _searchDebounce?.cancel();
    _searchInput = '';
    _searchQuery = '';
    notifyListeners();
  }

  void setSelectedLevel(String level) {
    _filters = level == 'Tous'
        ? _filters.copyWith(clearLevel: true)
        : _filters.copyWith(level: level);
    notifyListeners();
  }

  void applyFilters(GroupFilters filters) {
    if (filters == _filters) return;
    _filters = filters;
    notifyListeners();
  }

  void clearVisibilityFilter() =>
      applyFilters(_filters.copyWith(visibility: VisibilityFilter.all));

  void clearCapacityFilter() =>
      applyFilters(_filters.copyWith(capacity: CapacityFilter.all));

  void clearLevelFilter() => applyFilters(_filters.copyWith(clearLevel: true));

  void resetFilters() => applyFilters(GroupFilters.none);

  /// Clears both the search query and all advanced filters.
  void resetAllCriteria() {
    _searchDebounce?.cancel();
    _searchInput = '';
    _searchQuery = '';
    _filters = GroupFilters.none;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounce?.cancel();
    _changesSub?.cancel();
    _sessionSub?.cancel();
    _notices.close();
    super.dispose();
  }

  static const _notSignedIn = 'Vous devez être connecté.';
  static const _ownerOnly = 'Action réservée au créateur du groupe.';

  bool _deny(String message) {
    _errorMessage = message;
    notifyListeners();
    return false;
  }

  // ─── Group CRUD ────────────────────────────────────────────────────────────

  Future<bool> createGroup({
    required String name,
    required String description,
    required String level,
    required List<PublicProfile> selectedMembers,
    bool isPublic = true,
    int maxMembers = 10,
  }) async {
    if (!isSignedIn) return _deny(_notSignedIn);
    // Validation de sécurité au niveau du ViewModel
    final nameError = FormValidators.validateGroupName(name);
    if (nameError != null) {
      _errorMessage = nameError;
      notifyListeners();
      return false;
    }

    final descError = FormValidators.validateGroupDescription(description);
    if (descError != null) {
      _errorMessage = descError;
      notifyListeners();
      return false;
    }

    final capacityError = FormValidators.validateCapacity(
      maxMembers: maxMembers,
      selectedCount: selectedMembers.length,
    );
    if (capacityError != null) {
      _errorMessage = capacityError;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Le créateur doit toujours faire partie des membres du groupe
      final membersList = List<PublicProfile>.from(selectedMembers);
      if (!membersList.any((u) => u.id == currentUserId)) {
        final currentUser = await _repo.getUserById(currentUserId);
        if (currentUser != null) {
          membersList.insert(0, currentUser);
        }
      }

      final newGroup = Group(
        // Identifiant définitif attribué par le dépôt (Firestore).
        id: 'g_${DateTime.now().millisecondsSinceEpoch}',
        name: name.trim(),
        description: description.trim(),
        level: level,
        isPublic: isPublic,
        maxMembers: maxMembers,
        ownerId: currentUserId,
        members: membersList,
        createdAt: DateTime.now(),
      );

      final created = await _repo.addGroup(newGroup);
      _groups.insert(0, created);
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la création du groupe.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateGroup(Group group) async {
    if (!isOwnerOf(group.id)) return _deny(_ownerOnly);
    // Validation de sécurité au niveau du ViewModel
    final nameError = FormValidators.validateGroupName(group.name);
    if (nameError != null) {
      _errorMessage = nameError;
      notifyListeners();
      return false;
    }

    final descError = FormValidators.validateGroupDescription(group.description);
    if (descError != null) {
      _errorMessage = descError;
      notifyListeners();
      return false;
    }

    final capacityError = FormValidators.validateCapacity(
      maxMembers: group.maxMembers,
      selectedCount: group.members.length,
    );
    if (capacityError != null) {
      _errorMessage = capacityError;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _repo.updateGroup(group);
      final idx = _groups.indexWhere((g) => g.id == group.id);
      if (idx != -1) _groups[idx] = updated;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la modification du groupe.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteGroup(String groupId) async {
    if (!isOwnerOf(groupId)) return _deny(_ownerOnly);
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repo.deleteGroup(groupId);
      if (success) {
        _groups.removeWhere((g) => g.id == groupId);
        _pendingRequests.remove(groupId);
      }
      return success;
    } catch (e) {
      _errorMessage = 'Erreur lors de la suppression du groupe.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Group? getGroupById(String groupId) {
    try {
      return _groups.firstWhere((g) => g.id == groupId);
    } catch (_) {
      return null;
    }
  }

  // ─── Membership actions ────────────────────────────────────────────────────

  /// Current user joins a public group.
  ///
  /// Returns `null` on success, or a localised error string.
  Future<String?> joinGroup(String groupId) async {
    if (!isSignedIn) return _notSignedIn;
    final error = await _repo.joinGroup(groupId, currentUserId);
    if (error == null) await _refreshGroup(groupId);
    return error;
  }

  /// Current user leaves a group.
  Future<String?> leaveGroup(String groupId) async {
    if (!isSignedIn) return _notSignedIn;
    final error = await _repo.leaveGroup(groupId, currentUserId);
    if (error == null) {
      _userPendingGroupIds.remove(groupId);
      await _refreshGroup(groupId);
    }
    return error;
  }

  /// Current user sends a join request to a private group.
  Future<String?> sendJoinRequest(String groupId) async {
    if (!isSignedIn) return _notSignedIn;
    final uid = currentUserId;
    final error = await _repo.sendJoinRequest(groupId, uid);
    if (error == null) {
      _userPendingGroupIds.add(groupId);
      final req = await _repo.getPendingRequest(groupId, uid);
      if (req != null) {
        _pendingRequests.putIfAbsent(groupId, () => []).add(req);
      }
      notifyListeners();
    }
    return error;
  }

  /// Current user cancels their pending join request.
  Future<bool> cancelJoinRequest(String groupId) async {
    final success = await _repo.cancelJoinRequest(groupId, currentUserId);
    if (success) {
      _userPendingGroupIds.remove(groupId);
      _pendingRequests[groupId]
          ?.removeWhere((r) => r.userId == currentUserId);
      notifyListeners();
    }
    return success;
  }

  // ─── Owner actions ────────────────────────────────────────────────────────

  Future<String?> acceptRequest(JoinRequest request) async {
    if (!isOwnerOf(request.groupId)) return _ownerOnly;
    final error = await _repo.acceptJoinRequest(
      request.id,
      request.groupId,
      request.userId,
    );
    if (error == null) {
      if (request.userId == currentUserId) {
        _userPendingGroupIds.remove(request.groupId);
      }
      _pendingRequests[request.groupId]?.removeWhere((r) => r.id == request.id);
      await _refreshGroup(request.groupId);
    }
    return error;
  }

  Future<bool> rejectRequest(JoinRequest request) async {
    if (!isOwnerOf(request.groupId)) return false;
    final success = await _repo.rejectJoinRequest(request.id);
    if (success) {
      _pendingRequests[request.groupId]?.removeWhere((r) => r.id == request.id);
      notifyListeners();
    }
    return success;
  }

  Future<String?> removeMember(String groupId, String userId) async {
    if (!isOwnerOf(groupId)) return _ownerOnly;
    final error = await _repo.removeMember(groupId, userId);
    if (error == null) await _refreshGroup(groupId);
    return error;
  }

  /// Owner-initiated direct member addition (bypasses join-request flow).
  Future<String?> addMemberDirectly(String groupId, String userId) async {
    if (!isOwnerOf(groupId)) return _ownerOnly;
    final error = await _repo.joinGroup(groupId, userId);
    if (error == null) await _refreshGroup(groupId);
    return error;
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  Future<void> _refreshGroup(String groupId) async {
    final updated = await _repo.getGroupById(groupId);
    if (updated != null) {
      final idx = _groups.indexWhere((g) => g.id == groupId);
      if (idx != -1) {
        _groups[idx] = updated;
      }
    }
    notifyListeners();
  }
}

/// Notification liée aux groupes, affichée dans l'application.
class GroupNotice {
  final String message;

  /// Demande à traiter (propriétaire) ; `null` pour une simple information.
  final JoinRequest? request;

  const GroupNotice(this.message, {this.request});
}
