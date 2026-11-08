import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studymate/features/groups/models/book.dart';
import 'package:studymate/features/groups/services/google_books_service.dart';
import 'package:studymate/features/groups/viewmodels/book_suggestions_viewmodel.dart';

/// Réponse fictive au format de l'API Google Books (données inventées).
Map<String, Object?> _volume(String id, String title, {String? thumb, String view = 'PARTIAL'}) => {
      'id': id,
      'volumeInfo': {
        'title': title,
        'authors': ['Auteur Test'],
        'publishedDate': '2021-05-12',
        'pageCount': 320,
        'language': 'fr',
        'description': 'Description de test.',
        if (thumb != null) 'imageLinks': {'thumbnail': thumb},
        'infoLink': 'https://books.google.com/books?id=$id',
      },
      'accessInfo': {'viewability': view},
    };

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  setUp(GoogleBooksService.clearCache);

  group('GoogleBooksService (API externe Google Books)', () {
    test('appelle /books/v1/volumes sans clé et convertit les livres', () async {
      late Uri called;
      final service = GoogleBooksService(
        client: MockClient((req) async {
          called = req.url;
          return _json({
            'items': [
              _volume('a1', 'Livre Spring', thumb: 'http://books.google.com/cover.jpg'),
              _volume('a2', 'Livre JPA', view: 'ALL_PAGES'),
            ],
          });
        }),
      );

      final books = await service.search('Spring Boot');

      expect(called.host, 'www.googleapis.com');
      expect(called.path, '/books/v1/volumes');
      expect(called.queryParameters['q'], 'Spring Boot');
      expect(called.queryParameters.containsKey('key'), isFalse);
      expect(books, hasLength(2));
      expect(books.first.title, 'Livre Spring');
      expect(books.first.year, '2021');
      expect(books.first.thumbnailUrl, startsWith('https://'), reason: 'HTTP forcé en HTTPS');
      expect(books.first.hasPreview, isTrue);
      expect(books[1].isFreeToRead, isTrue);
    });

    test('supprime les doublons et ignore les livres sans titre', () async {
      final service = GoogleBooksService(
        client: MockClient((_) async => _json({
              'items': [
                _volume('a1', 'Même titre'),
                _volume('a2', 'Même titre'),
                {'id': 'x', 'volumeInfo': {'title': ''}},
              ],
            })),
      );
      expect(await service.search('test'), hasLength(1));
    });

    test('aucun résultat : liste vide', () async {
      final service = GoogleBooksService(client: MockClient((_) async => _json({'totalItems': 0})));
      expect(await service.search('zzzz'), isEmpty);
    });

    test('met en cache : un seul appel réseau pour la même recherche', () async {
      var calls = 0;
      final service = GoogleBooksService(
        client: MockClient((_) async {
          calls++;
          return _json({'items': [_volume('a1', 'Livre')]});
        }),
      );
      await service.search('Docker');
      await service.search('  docker ');
      expect(calls, 1);
    });

    test('erreurs traduites en français', () async {
      final offline = GoogleBooksService(
        client: MockClient((_) async => throw const SocketException('offline')),
      );
      await expectLater(
        offline.search('Java'),
        throwsA(isA<BooksException>().having((e) => e.message, 'message', contains('connexion'))),
      );

      final busy = GoogleBooksService(client: MockClient((_) async => _json({}, 429)));
      await expectLater(busy.search('Java'), throwsA(isA<BooksException>()));
    });
  });

  group('Relais Open Library (quota Google Books épuisé)', () {
    test('Google Books répond 429 : résultats d\'Open Library', () async {
      final hosts = <String>[];
      final service = GoogleBooksService(
        client: MockClient((req) async {
          hosts.add(req.url.host);
          if (req.url.host == 'www.googleapis.com') return _json({'error': {'code': 429}}, 429);
          expect(req.url.path, '/search.json');
          return _json({
            'docs': [
              {
                'key': '/works/OL1W',
                'title': 'Livre Open Library',
                'author_name': ['Auteur OL'],
                'first_publish_year': 2018,
                'cover_i': 123,
                'number_of_pages_median': 140,
                'ebook_access': 'public',
              },
            ],
          });
        }),
      );

      final books = await service.search('Spring Boot');

      expect(hosts, ['www.googleapis.com', 'openlibrary.org']);
      final b = books.single;
      expect(b.source, 'Open Library');
      expect(b.title, 'Livre Open Library');
      expect(b.authorsLabel, 'Auteur OL');
      expect(b.year, '2018');
      expect(b.thumbnailUrl, 'https://covers.openlibrary.org/b/id/123-M.jpg');
      expect(b.infoLink, 'https://openlibrary.org/works/OL1W');
      expect(b.isFreeToRead, isTrue);
    });

    test('les deux APIs échouent : message d\'erreur de Google Books', () async {
      final service = GoogleBooksService(client: MockClient((_) async => _json({}, 429)));
      await expectLater(
        service.search('Java'),
        throwsA(isA<BooksException>().having((e) => e.message, 'message', contains('Trop de recherches'))),
      );
    });
  });

  group('Requête construite à partir du groupe', () {
    test('utilise le nom du groupe', () {
      expect(
        GoogleBooksService.queryForGroup(name: 'Spring Boot Masters', description: 'x'),
        'Spring Boot Masters',
      );
    });

    test('nom générique : mots-clés de la description', () {
      final q = GoogleBooksService.queryForGroup(
        name: 'Groupe 1',
        description: 'Révision des conteneurs Docker et Kubernetes pour les examens',
      );
      expect(q, contains('Docker'));
      expect(q, contains('Kubernetes'));
      expect(q.toLowerCase(), isNot(contains('groupe')));
    });
  });

  group('BookSuggestionsViewModel', () {
    test('charge les suggestions, puis une recherche personnalisée', () async {
      final vm = BookSuggestionsViewModel(
        groupName: 'Spring Boot',
        groupDescription: 'APIs REST',
        service: GoogleBooksService(
          client: MockClient((req) async => _json({
                'items': [_volume('id-${req.url.queryParameters['q']}', 'Livre ${req.url.queryParameters['q']}')],
              })),
        ),
      );
      await vm.loadInitial();
      expect(vm.books.single.title, 'Livre Spring Boot');
      expect(vm.isCustomQuery, isFalse);

      await vm.search('Spring Security');
      expect(vm.books.single.title, 'Livre Spring Security');
      expect(vm.isCustomQuery, isTrue);
    });

    test('nom sans résultat : nouvel essai avec la description', () async {
      final queries = <String>[];
      final vm = BookSuggestionsViewModel(
        groupName: 'Projet Alpha',
        groupDescription: 'Algorithmes et structures de données',
        service: GoogleBooksService(
          client: MockClient((req) async {
            final q = req.url.queryParameters['q']!;
            queries.add(q);
            return q == 'Projet Alpha' ? _json({}) : _json({'items': [_volume('b', 'Algo')]});
          }),
        ),
      );
      await vm.loadInitial();
      expect(queries, hasLength(2));
      expect(vm.books.single.title, 'Algo');
    });

    test('erreur réseau exposée avec possibilité de réessayer', () async {
      var fail = true;
      final vm = BookSuggestionsViewModel(
        groupName: 'Java',
        groupDescription: '',
        service: GoogleBooksService(
          client: MockClient((_) async {
            if (fail) throw const SocketException('offline');
            return _json({'items': [_volume('j', 'Java')]});
          }),
        ),
      );
      await vm.loadInitial();
      expect(vm.error, isNotNull);
      fail = false;
      await vm.retry();
      expect(vm.error, isNull);
      expect(vm.books, hasLength(1));
    });

    test('message de partage dans le chat', () {
      final book = Book.fromJson(_volume('z', 'Titre test') as Map<String, dynamic>)!;
      final msg = BookSuggestionsViewModel.chatMessageFor(book);
      expect(msg, startsWith('📚 Livre recommandé : Titre test'));
      expect(msg, contains('Auteur Test'));
      expect(msg, contains('https://books.google.com/books?id=z'));
    });
  });
}
