import 'package:flutter/foundation.dart';
import '../../../core/constants/session_user.dart';
import '../../../core/services/group_membership.dart';
import '../models/resource.dart';
import '../repositories/resource_repository.dart';

class ResourceViewModel extends ChangeNotifier {
  ResourceViewModel(this._repository, {GroupMembershipSource? groups}) {
    attachGroups(groups);
  }

  final ResourceRepository _repository;

  /// Groupes de l'utilisateur (module Groupes). `null` = aucun groupe connu :
  /// les ressources « réservées à un groupe » ne sont alors visibles que par
  /// leur propriétaire.
  GroupMembershipSource? _groups;

  /// Branche (ou remplace) la source d'appartenance aux groupes.
  void attachGroups(GroupMembershipSource? groups) {
    if (identical(groups, _groups)) return;
    _groups?.removeListener(notifyListeners);
    _groups = groups;
    _groups?.addListener(notifyListeners);
    notifyListeners();
  }

  /// Groupes auxquels l'utilisateur peut associer une ressource.
  List<GroupRef> get selectableGroups => _groups?.memberGroups ?? const [];

  /// Règle d'accès unique (liste, détail, page du groupe) :
  /// - le propriétaire voit toujours ses ressources ;
  /// - « privée » : propriétaire uniquement ;
  /// - « groupe » : membres du groupe uniquement (public ou privé) ;
  /// - « publique » : tout utilisateur connecté.
  /// Le statut payant/gratuit n'est pas modifié par l'appartenance au groupe.
  bool canView(Resource r) {
    if (r.isOwnedByMe) return true;
    return switch (r.visibility) {
      ResourceVisibility.public => true,
      ResourceVisibility.private => false,
      ResourceVisibility.group =>
        r.groupId != null && (_groups?.memberGroupIds.contains(r.groupId) ?? false),
    };
  }

  /// Ressources associées à un groupe, filtrées par [canView].
  List<Resource> resourcesForGroup(String groupId) => _all
      .where((r) => r.visibility == ResourceVisibility.group && r.groupId == groupId && canView(r))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Resource> _all = [];
  List<Flashcard> flashcards = [];
  bool loading = true;
  String query = '';
  String filter = 'Tout';
  String? sort;
  String? error;
  int resetToken = 0;
  bool loadedOnce = false;
  String loadedFor = '';

  List<Resource> get visibleResources {
    var list = _all.where(canView);
    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      list = list.where((r) =>
          r.title.toLowerCase().contains(q) ||
          r.subject.toLowerCase().contains(q) ||
          r.author.toLowerCase().contains(q));
    }
    list = list.where((r) => switch (filter) {
          'Gratuit' => r.isFree,
          'Payant' => !r.isFree,
          'Public' => r.visibility == ResourceVisibility.public,
          'Privé' => r.visibility == ResourceVisibility.private,
          'Groupe' => r.visibility == ResourceVisibility.group,
          'Favoris' => r.isFavorite,
          _ => true,
        });
    final items = list.toList();
    final oldestFirst = sort == 'Plus ancien';
    items.sort((a, b) {
      final byDate = a.createdAt.compareTo(b.createdAt);
      if (byDate != 0) return oldestFirst ? byDate : -byDate;
      final byId = (a.id ?? 0).compareTo(b.id ?? 0);
      return oldestFirst ? byId : -byId;
    });
    return items;
  }

  Resource? byId(int id) {
    for (final r in _all) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Seul un enseignant crée des ressources ; l'étudiant consulte et favori.
  bool get canCreate => SessionUser.isTeacher;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _all = await _repository.getAll();
      await SessionUser.refreshRole();
    } catch (e) {
      debugPrint('ResourceViewModel.load: $e');
      error = 'Impossible de charger les ressources.';
    } finally {
      loading = false;
      loadedOnce = true;
      loadedFor = SessionUser.email;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  void setFilter(String value) {
    if (value == 'Plus récent' || value == 'Plus ancien') {
      sort = value;
    } else {
      filter = value;
    }
    notifyListeners();
  }

  void clearFilters() {
    query = '';
    filter = 'Tout';
    sort = null;
    resetToken++;
    notifyListeners();
  }

  Future<void> save(Resource resource) async {
    if (!SessionUser.isTeacher) {
      throw StateError('Seuls les enseignants peuvent gérer les ressources.');
    }
    final existing = resource.id == null ? null : byId(resource.id!);
    if (existing != null && !existing.isOwnedByMe) {
      throw StateError('Seul le propriétaire peut modifier cette ressource.');
    }
    if (resource.visibility == ResourceVisibility.group) {
      final gid = resource.groupId;
      final unchanged = existing != null && existing.groupId == gid;
      final member = _groups?.memberGroupIds.contains(gid) ?? false;
      if (gid == null || (!unchanged && !member)) {
        throw StateError('Choisissez un groupe dont vous êtes membre.');
      }
    }
    if (resource.id == null) {
      await _repository.create(resource);
    } else {
      await _repository.update(resource);
    }
    await load();
  }

  Future<void> remove(int id) async {
    if (!SessionUser.isTeacher) {
      throw StateError('Seuls les enseignants peuvent gérer les ressources.');
    }
    final existing = byId(id);
    if (existing != null && !existing.isOwnedByMe) {
      throw StateError('Seul le propriétaire peut supprimer cette ressource.');
    }
    await _repository.delete(id);
    await load();
  }

  Future<void> toggleFavorite(Resource resource) async {
    if (resource.id == null) return;
    await _repository.update(resource.copyWith(isFavorite: !resource.isFavorite));
    await load();
  }

  Future<String> summarize(Resource resource) async {
    final summary = await _repository.generateSummary(resource);
    await load();
    return summary;
  }

  Future<List<Flashcard>> generateFlashcards(Resource resource) async {
    flashcards = await _repository.generateFlashcards(resource);
    notifyListeners();
    return flashcards;
  }
}
