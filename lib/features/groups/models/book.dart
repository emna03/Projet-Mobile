/// Livre suggéré par l'API Google Books pour un groupe d'étude.
class Book {
  final String id;
  final String title;
  final List<String> authors;
  final String? publishedDate;
  final int? pageCount;
  final String? language;
  final String? description;
  final String? thumbnailUrl;
  final String? infoLink;

  /// `ALL_PAGES` (lecture gratuite), `PARTIAL` (aperçu) ou `NO_PAGES`.
  final String viewability;

  /// API d'origine : « Google Books » ou « Open Library ».
  final String source;

  const Book({
    required this.id,
    required this.title,
    this.authors = const [],
    this.publishedDate,
    this.pageCount,
    this.language,
    this.description,
    this.thumbnailUrl,
    this.infoLink,
    this.viewability = 'NO_PAGES',
    this.source = 'Google Books',
  });

  String get authorsLabel => authors.isEmpty ? 'Auteur inconnu' : authors.join(', ');

  /// Année de publication (« 2021 » pour « 2021-05-12 »).
  String? get year =>
      publishedDate == null || publishedDate!.length < 4 ? publishedDate : publishedDate!.substring(0, 4);

  bool get isFreeToRead => viewability == 'ALL_PAGES';
  bool get hasPreview => viewability == 'PARTIAL' || isFreeToRead;

  /// Construit un livre à partir d'un élément `items[]` de l'API Google Books.
  /// Renvoie `null` si l'élément n'a pas de titre.
  static Book? fromJson(Map<String, dynamic> json) {
    final info = json['volumeInfo'];
    if (info is! Map) return null;
    final title = (info['title'] as String? ?? '').trim();
    if (title.isEmpty) return null;
    final subtitle = (info['subtitle'] as String? ?? '').trim();
    final images = info['imageLinks'];
    final thumb = images is Map
        ? (images['thumbnail'] ?? images['smallThumbnail']) as String?
        : null;
    final access = json['accessInfo'];
    return Book(
      id: json['id'] as String? ?? title,
      title: subtitle.isEmpty ? title : '$title : $subtitle',
      authors: List<String>.from(info['authors'] as List? ?? const []),
      publishedDate: info['publishedDate'] as String?,
      pageCount: (info['pageCount'] as num?)?.toInt(),
      language: info['language'] as String?,
      description: (info['description'] as String?)?.trim(),
      // Android bloque le HTTP en clair : on force HTTPS pour les couvertures.
      thumbnailUrl: thumb?.replaceFirst('http://', 'https://'),
      infoLink: (info['infoLink'] ?? info['canonicalVolumeLink']) as String?,
      viewability: access is Map ? access['viewability'] as String? ?? 'NO_PAGES' : 'NO_PAGES',
    );
  }

  /// Construit un livre à partir d'un élément `docs[]` de l'API Open Library
  /// (`/search.json`). Renvoie `null` si l'élément n'a pas de titre.
  static Book? fromOpenLibrary(Map<String, dynamic> json) {
    final title = (json['title'] as String? ?? '').trim();
    if (title.isEmpty) return null;
    final key = json['key'] as String? ?? title;
    final cover = (json['cover_i'] as num?)?.toInt();
    final year = (json['first_publish_year'] as num?)?.toInt();
    final languages = List<String>.from(json['language'] as List? ?? const []);
    return Book(
      id: key,
      title: title,
      authors: List<String>.from(json['author_name'] as List? ?? const []),
      publishedDate: year?.toString(),
      pageCount: (json['number_of_pages_median'] as num?)?.toInt(),
      language: languages.isEmpty ? null : languages.first,
      thumbnailUrl: cover == null ? null : 'https://covers.openlibrary.org/b/id/$cover-M.jpg',
      infoLink: key.startsWith('/') ? 'https://openlibrary.org$key' : null,
      viewability: switch (json['ebook_access']) {
        'public' => 'ALL_PAGES',
        'borrowable' => 'PARTIAL',
        _ => 'NO_PAGES',
      },
      source: 'Open Library',
    );
  }
}
