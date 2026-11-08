import 'package:flutter/foundation.dart';

import '../models/book.dart';
import '../services/google_books_service.dart';

/// État de la section « Livres recommandés » d'un groupe.
class BookSuggestionsViewModel extends ChangeNotifier {
  BookSuggestionsViewModel({
    required String groupName,
    required String groupDescription,
    GoogleBooksService? service,
  })  : _service = service ?? GoogleBooksService(),
        _ownsService = service == null,
        _description = groupDescription,
        autoQuery = GoogleBooksService.queryForGroup(
          name: groupName,
          description: groupDescription,
        ) {
    _query = autoQuery;
  }

  final GoogleBooksService _service;
  final bool _ownsService;
  final String _description;

  /// Requête construite automatiquement à partir du groupe.
  final String autoQuery;

  String _query = '';
  List<Book> _books = const [];
  bool _isLoading = false;
  String? _error;
  bool _loaded = false;
  bool _disposed = false;

  String get query => _query;
  List<Book> get books => _books;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get loaded => _loaded;
  bool get isCustomQuery => _query != autoQuery;

  /// API qui a fourni les résultats affichés (Google Books ou Open Library).
  String get source => _books.isEmpty ? 'Google Books' : _books.first.source;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Charge les suggestions automatiques (une seule fois).
  Future<void> loadInitial() async {
    if (_loaded || _isLoading) return;
    await search(autoQuery, fallbackToDescription: true);
  }

  /// Recherche personnalisée (« Spring Security »…). Vide = retour aux
  /// suggestions automatiques.
  Future<void> search(String text, {bool fallbackToDescription = false}) async {
    final q = text.trim().isEmpty ? autoQuery : text.trim();
    _query = q;
    _isLoading = true;
    _error = null;
    _notify();
    try {
      var result = await _service.search(q);
      if (result.isEmpty && fallbackToDescription) {
        // Nom sans résultat : on retente avec les mots-clés de la description.
        final alt = GoogleBooksService.keywordsOf(_description).take(3).join(' ');
        if (alt.isNotEmpty && alt.toLowerCase() != q.toLowerCase()) {
          result = await _service.search(alt);
        }
      }
      _books = result;
    } on BooksException catch (e) {
      _error = e.message;
      _books = const [];
    } catch (e) {
      debugPrint('BookSuggestionsViewModel: $e');
      _error = 'Impossible de charger les livres.';
      _books = const [];
    } finally {
      _isLoading = false;
      _loaded = true;
      _notify();
    }
  }

  Future<void> retry() => search(_query, fallbackToDescription: !isCustomQuery);

  /// Texte du message publié dans le chat du groupe.
  static String chatMessageFor(Book book) {
    final buffer = StringBuffer('📚 Livre recommandé : ${book.title}')
      ..write(' — ${book.authorsLabel}');
    if (book.year != null) buffer.write(' (${book.year})');
    if (book.infoLink != null) buffer.write('\n${book.infoLink}');
    return buffer.toString();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_ownsService) _service.dispose();
    super.dispose();
  }
}
