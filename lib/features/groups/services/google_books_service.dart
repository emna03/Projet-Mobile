import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/book.dart';

/// Erreur de l'API Google Books, avec un message en français.
class BooksException implements Exception {
  final String message;
  const BooksException(this.message);
  @override
  String toString() => message;
}

/// API externe **Google Books** (sans clé) : suggestions de livres liés au
/// sujet d'un groupe d'étude.
///
/// `GET https://www.googleapis.com/books/v1/volumes?q=...`
class GoogleBooksService {
  GoogleBooksService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _host = 'www.googleapis.com';
  static const _path = '/books/v1/volumes';
  static const _timeout = Duration(seconds: 15);

  /// Clé facultative (`--dart-define=GOOGLE_BOOKS_API_KEY=...`) : l'API fonctionne
  /// sans clé, mais avec un quota limité par adresse IP.
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

    final uri = Uri.https(_host, _path, {
      'q': q,
      'maxResults': '$maxResults',
      'orderBy': 'relevance',
      'printType': 'books',
      if (_apiKey.isNotEmpty) 'key': _apiKey,
    });

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const BooksException('Google Books met trop de temps à répondre. Réessayez.');
    } on SocketException {
      throw const BooksException('Impossible de charger les livres. Vérifiez votre connexion.');
    } on http.ClientException {
      throw const BooksException('Impossible de charger les livres. Vérifiez votre connexion.');
    }

    if (response.statusCode == 429) {
      throw const BooksException('Trop de recherches. Patientez quelques instants.');
    }
    if (response.statusCode != 200) {
      throw BooksException('Google Books est indisponible (code ${response.statusCode}).');
    }

    final Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const BooksException('Réponse de Google Books illisible.');
    }
    final items = json is Map ? json['items'] : null;
    final books = <Book>[];
    final seen = <String>{};
    if (items is List) {
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final book = Book.fromJson(item);
        // Les éditions multiples d'un même titre sont fréquentes.
        if (book != null && seen.add(book.title.toLowerCase())) books.add(book);
      }
    }
    _cache[key] = books;
    return books;
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
