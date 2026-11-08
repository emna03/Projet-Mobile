import 'package:flutter/foundation.dart';
import '../../../core/constants/session_user.dart';
import '../models/resource.dart';
import '../repositories/resource_repository.dart';

class ResourceViewModel extends ChangeNotifier {
  ResourceViewModel(this._repository);

  final ResourceRepository _repository;

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
    final mine = SessionUser.email;
    var list = _all.where((r) {
      if (r.visibility == ResourceVisibility.private) return r.ownerName == mine;
      return true;
    });
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
