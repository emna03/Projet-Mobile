import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/book.dart';

/// Erreur de recherche de livres, avec un message en français.
class BooksException implements Exception {
  final String message;
  const BooksException(this.message);
  @override
  String toString() => message;
}

/// Suggestions de livres liés au sujet d'un groupe d'étude.
///
/// APIs externes (sans clé) :
/// 1. **Google Books** — `GET https://www.googleapis.com/books/v1/volumes?q=...`
/// 2. **Open Library** — `GET https://openlibrary.org/search.json?q=...`,
///    utilisée automatiquement si Google Books refuse ou échoue.
///
/// Pourquoi un relais : sans clé, Google Books décompte toutes les requêtes
/// anonymes sur un quota journalier commun à toutes les applications ; quand
/// il est épuisé, l'API répond 429 (« Quota exceeded … Queries per day »).
class GoogleBooksService {
  GoogleBooksService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  /// Clé facultative (`--dart-define=GOOGLE_BOOKS_API_KEY=...`) : avec une clé,
  /// Google Books utilise le quota de votre propre projet (1 000 requêtes/jour).
  static const _apiKey = String.fromEnvironment('GOOGLE_BOOKS_API_KEY');

  /// Résultats déjà chargés (clé = requête normalisée) : pas de nouvel appel
  /// réseau à chaque ouverture de la page d'un groupe.
  static final Map<String, List<Book>> _cache = {};

  static void clearCache() => _cache.clear();

  /// Recherche des livres pour [query] (ex. « Spring Boot JPA »).
  Future<List<Book>> search(String query, {int maxResults = 6}) async {
    final q = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (q.isEmpty) return const [];
    final key = '${q.toLowerCase()}|$maxResults';
    final cached = _cache[key];
    if (cached != null) return cached;

    List<Book> books;
    try {
      books = await _searchGoogleBooks(q, maxResults);
    } on BooksException catch (googleError) {
      debugPrint('Google Books indisponible (${googleError.message}) → Open Library');
      try {
        books = await _searchOpenLibrary(q, maxResults);
      } on BooksException {
        throw googleError;
      }
    }
    _cache[key] = books;
    return books;
  }

  // ─── Google Books ──────────────────────────────────────────────────────────

  Future<List<Book>> _searchGoogleBooks(String q, int maxResults) async {
    final uri = Uri.https('www.googleapis.com', '/books/v1/volumes', {
      'q': q,
      'maxResults': '$maxResults',
      'orderBy': 'relevance',
      'printType': 'books',
      if (_apiKey.isNotEmpty) 'key': _apiKey,
    });
    final json = await _getJson(uri);
    final items = json is Map ? json['items'] : null;
    return _unique([
      if (items is List)
        for (final item in items)
          if (item is Map<String, dynamic>) Book.fromJson(item),
    ]);
  }

  // ─── Open Library (relais) ─────────────────────────────────────────────────

  Future<List<Book>> _searchOpenLibrary(String q, int maxResults) async {
    final uri = Uri.https('openlibrary.org', '/search.json', {
      'q': q,
      'limit': '$maxResults',
      'fields': 'key,title,author_name,first_publish_year,cover_i,'
          'number_of_pages_median,language,ebook_access',
    });
    final json = await _getJson(uri);
    final docs = json is Map ? json['docs'] : null;
    return _unique([
      if (docs is List)
        for (final doc in docs)
          if (doc is Map<String, dynamic>) Book.fromOpenLibrary(doc),
    ]);
  }

  // ─── Commun ────────────────────────────────────────────────────────────────

  Future<Object?> _getJson(Uri uri) async {
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const BooksException('Le service de livres met trop de temps à répondre. Réessayez.');
    } on SocketException {
      throw const BooksException('Impossible de charger les livres. Vérifiez votre connexion.');
    } on http.ClientException {
      throw const BooksException('Impossible de charger les livres. Vérifiez votre connexion.');
    }

    if (response.statusCode == 429) {
      throw const BooksException('Trop de recherches. Patientez quelques instants.');
    }
    if (response.statusCode != 200) {
      throw BooksException('Service de livres indisponible (code ${response.statusCode}).');
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const BooksException('Réponse du service de livres illisible.');
    }
  }

  /// Retire les livres sans titre et les éditions en double d'un même titre.
  static List<Book> _unique(List<Book?> raw) {
    final seen = <String>{};
    return [
      for (final b in raw)
        if (b != null && seen.add(b.title.toLowerCase())) b,
    ];
  }

  /// Requête automatique pour un groupe : son nom, ou à défaut les mots
  /// significatifs de la description (nom trop générique, ex. « Groupe 1 »).
  static String queryForGroup({required String name, required String description}) {
    final cleanName = name.replaceAll(RegExp(r'\b(groupe|group|grp|team|équipe)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^\p{L}\p{N}+#. ]', unicode: true), ' ')
        .trim();
    final meaningful = cleanName.replaceAll(RegExp(r'[0-9\s]'), '');
    if (meaningful.length >= 3) return cleanName;
    return keywordsOf(description).take(4).join(' ');
  }

  /// Mots significatifs d'un texte (sans les mots vides français).
  static List<String> keywordsOf(String text) {
    const stop = {
      'les', 'des', 'une', 'pour', 'dans', 'avec', 'sur', 'par', 'aux', 'que', 'qui', 'est',
      'son', 'ses', 'leur', 'nos', 'vos', 'groupe', 'étude', 'etude', 'étudiants', 'etudiants',
      'entraide', 'cours', 'révision', 'revision', 'apprentissage', 'membres', 'et', 'de', 'du',
      'la', 'le', 'en', 'un', 'à', 'au', 'ce', 'cette', 'ces', 'plus', 'très', 'tout', 'tous',
    };
    return text
        .split(RegExp(r'[^\p{L}\p{N}+#]+', unicode: true))
        .where((w) => w.length >= 3 && !stop.contains(w.toLowerCase()))
        .toList();
  }

  void dispose() => _client.close();
}
