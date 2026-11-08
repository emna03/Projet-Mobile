import 'package:sqflite/sqflite.dart';

import '../../data/quiz_local_database.dart';
import '../models/knowledge_concept.dart';
import '../models/knowledge_edge.dart';
import '../models/question_concept_link.dart';
import '../models/student_concept_mastery.dart';

class KnowledgeGraphRepository {
  KnowledgeGraphRepository({QuizLocalDatabase? database})
      : _dbProvider = database ?? QuizLocalDatabase.instance;

  final QuizLocalDatabase _dbProvider;

  Future<Database> get _db => _dbProvider.database;

  Future<void> upsertConcept(KnowledgeConcept concept) async {
    final db = await _db;
    await db.insert(
      'kg_concepts',
      concept.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<KnowledgeConcept?> findByCanonical(String canonical) async {
    final db = await _db;
    final rows = await db.query(
      'kg_concepts',
      where: 'canonical_name = ?',
      whereArgs: [canonical],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return KnowledgeConcept.fromMap(rows.first);
  }

  Future<List<KnowledgeConcept>> listConcepts({String? subject}) async {
    final db = await _db;
    final rows = subject == null || subject.isEmpty
        ? await db.query('kg_concepts', orderBy: 'display_name ASC')
        : await db.query(
            'kg_concepts',
            where: 'subject = ?',
            whereArgs: [subject],
            orderBy: 'display_name ASC',
          );
    return rows.map(KnowledgeConcept.fromMap).toList();
  }

  Future<void> upsertEdge(KnowledgeEdge edge) async {
    final db = await _db;
    await db.insert(
      'kg_edges',
      edge.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<KnowledgeEdge>> listEdges() async {
    final db = await _db;
    final rows = await db.query('kg_edges');
    return rows.map(KnowledgeEdge.fromMap).toList();
  }

  Future<void> upsertQuestionConcept(QuestionConceptLink link) async {
    final db = await _db;
    await db.insert(
      'kg_question_concepts',
      link.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<QuestionConceptLink>> linksForQuiz(String quizId) async {
    final db = await _db;
    final rows = await db.query(
      'kg_question_concepts',
      where: 'quiz_id = ?',
      whereArgs: [quizId],
    );
    return rows.map(QuestionConceptLink.fromMap).toList();
  }

  Future<List<QuestionConceptLink>> allLinks() async {
    final db = await _db;
    final rows = await db.query('kg_question_concepts');
    return rows.map(QuestionConceptLink.fromMap).toList();
  }

  Future<void> upsertMastery(StudentConceptMastery mastery) async {
    final db = await _db;
    await db.insert(
      'kg_student_mastery',
      mastery.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<StudentConceptMastery>> masteryForUser(String userId) async {
    final db = await _db;
    final rows = await db.query(
      'kg_student_mastery',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows.map(StudentConceptMastery.fromMap).toList();
  }

  Future<Map<String, dynamic>?> getExtractionCache(String quizId) async {
    final db = await _db;
    final rows = await db.query(
      'kg_extraction_cache',
      where: 'quiz_id = ?',
      whereArgs: [quizId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> saveExtractionCache({
    required String quizId,
    required String contentHash,
    required String payloadJson,
    required String source,
  }) async {
    final db = await _db;
    await db.insert(
      'kg_extraction_cache',
      {
        'quiz_id': quizId,
        'content_hash': contentHash,
        'payload_json': payloadJson,
        'source': source,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
