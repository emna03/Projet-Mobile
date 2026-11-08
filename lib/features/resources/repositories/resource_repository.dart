import 'package:flutter/foundation.dart';

import '../../../core/utils/app_database.dart';
import '../../../core/utils/pdf_storage.dart';
import '../models/resource.dart';
import '../services/ai_resource_service.dart';

class ResourceRepository {
  final AiResourceService _ai = AiResourceService();

  // Sur mobile/desktop le fichier est sur disque : charger le BLOB ferait
  // dépasser la CursorWindow SQLite (2 Mo) et casserait le chargement.
  static const _columnsWithoutBytes = [
    'id', 'title', 'subject', 'author', 'owner_name', 'content', 'visibility',
    'group_id', 'group_name', 'is_free', 'price', 'pages', 'summary',
    'pdf_path', 'pdf_name', 'created_at', 'is_favorite',
  ];

  Future<List<Resource>> getAll() async {
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'resources',
      columns: kIsWeb ? null : _columnsWithoutBytes,
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(Resource.fromMap).toList();
  }

  Future<Resource?> getById(int id) async {
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'resources',
      columns: kIsWeb ? null : _columnsWithoutBytes,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Resource.fromMap(rows.first);
  }

  Future<int> create(Resource resource) async {
    final db = await AppDatabase.instance();
    return db.insert('resources', resource.toMap());
  }

  Future<int> update(Resource resource) async {
    final db = await AppDatabase.instance();
    return db.update('resources', resource.toMap(), where: 'id = ?', whereArgs: [resource.id]);
  }

  Future<int> delete(int id) async {
    final existing = await getById(id);
    await PdfStorage.delete(existing?.pdfPath);
    final db = await AppDatabase.instance();
    await db.delete('flashcards', where: 'resource_id = ?', whereArgs: [id]);
    return db.delete('resources', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> generateSummary(Resource resource) async {
    final summary = await _ai.summarize(resource);
    final updated = resource.copyWith(summary: summary);
    await update(updated);
    return summary;
  }

  Future<List<Flashcard>> getFlashcards(int resourceId) async {
    final db = await AppDatabase.instance();
    final rows = await db.query('flashcards', where: 'resource_id = ?', whereArgs: [resourceId], orderBy: 'id ASC');
    return rows.map(Flashcard.fromMap).toList();
  }

  Future<List<Flashcard>> generateFlashcards(Resource resource) async {
    final id = resource.id;
    if (id == null) return const [];
    final db = await AppDatabase.instance();
    await db.delete('flashcards', where: 'resource_id = ?', whereArgs: [id]);
    final cards = await _ai.flashcards(resource);
    for (final card in cards) {
      await db.insert('flashcards', card.toMap());
    }
    return getFlashcards(id);
  }
}
