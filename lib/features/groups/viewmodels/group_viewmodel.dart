import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/auth/app_session.dart';
import '../../../core/utils/validators.dart';
import '../../users/models/user.dart';
import '../models/group.dart';
import '../models/group_filters.dart';
import '../models/join_request.dart';
import '../repositories/group_repository.dart';

/// ViewModel managing state and UI interaction for all group-related screens.
///
/// Uses [ChangeNotifier] + [ListenableBuilder] as in the original app.
/// All database access goes through [GroupRepository].
class GroupViewModel extends ChangeNotifier {
  GroupViewModel({GroupRepository? repository})
      : _repo = repository ?? GroupRepository() {
    loadData();
  }

  final GroupRepository _repo;

  // ─── State ─────────────────────────────────────────────────────────────────

  List<Group> _groups = [];
  List<User> _allUsers = [];
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
  List<User> get allUsers => _allUsers;
  bool get isLoading => _isLoading;
  String get searchInput => _searchInput;
  String get searchQuery => _searchQuery;
  GroupFilters get filters => _filters;
  String get selectedLevel => _filters.level ?? 'Tous';
  String? get errorMessage => _errorMessage;
  String get currentUserId => AppSession.currentUserId;

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

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allUsers = List<User>.from(await _repo.getAllUsers());
      _groups = List<Group>.from(await _repo.getGroups());
      await _loadPendingRequests();
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des données.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadPendingRequests() async {
    final ownedGroupIds =
        _groups.where((g) => g.ownerId == currentUserId).map((g) => g.id);

    final map = <String, List<JoinRequest>>{};
    for (final gid in ownedGroupIds) {
      map[gid] = await _repo.getPendingRequests(gid);
    }
    _pendingRequests = map;

    final myRequests = await _repo.getPendingRequestsForUser(currentUserId);
    _userPendingGroupIds = myRequests.map((r) => r.groupId).toSet();
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
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ─── Group CRUD ────────────────────────────────────────────────────────────

  Future<bool> createGroup({
    required String name,
    required String description,
    required String level,
    required List<User> selectedMembers,
    bool isPublic = true,
    int maxMembers = 10,
  }) async {
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
      final membersList = List<User>.from(selectedMembers);
      if (!membersList.any((u) => u.id == currentUserId)) {
        final currentUser = await _repo.getUserById(currentUserId);
        if (currentUser != null) {
          membersList.insert(0, currentUser);
        }
      }

      final newGroup = Group(
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
    final error = await _repo.joinGroup(groupId, currentUserId);
    if (error == null) await _refreshGroup(groupId);
    return error;
  }

  /// Current user leaves a group.
  Future<String?> leaveGroup(String groupId) async {
    final error = await _repo.leaveGroup(groupId, currentUserId);
    if (error == null) {
      _userPendingGroupIds.remove(groupId);
      await _refreshGroup(groupId);
    }
    return error;
  }

  /// Current user sends a join request to a private group.
  Future<String?> sendJoinRequest(String groupId) async {
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
    final success = await _repo.rejectJoinRequest(request.id);
    if (success) {
      _pendingRequests[request.groupId]?.removeWhere((r) => r.id == request.id);
      notifyListeners();
    }
    return success;
  }

  Future<String?> removeMember(String groupId, String userId) async {
    final error = await _repo.removeMember(groupId, userId);
    if (error == null) await _refreshGroup(groupId);
    return error;
  }

  /// Owner-initiated direct member addition (bypasses join-request flow).
  Future<String?> addMemberDirectly(String groupId, String userId) async {
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
