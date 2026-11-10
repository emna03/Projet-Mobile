import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/question.dart';
import '../../models/quiz.dart';
import '../../services/ai_json_parser.dart';
import '../../services/quiz_ai_provider.dart';
import 'concept_normalizer.dart';
import 'local_llm/kg_llm_config.dart';

class ExtractedConceptDraft {
  const ExtractedConceptDraft({
    required this.name,
    this.description = '',
    this.questionIds = const [],
    this.skills = const [],
  });

  final String name;
  final String description;
  final List<String> questionIds;
  final List<String> skills;
}

class ExtractedRelationDraft {
  const ExtractedRelationDraft({
    required this.from,
    required this.to,
    required this.type,
    this.justification = '',
  });

  final String from;
  final String to;
  final String type;
  final String justification;
}

class ConceptExtractionResult {
  const ConceptExtractionResult({
    required this.concepts,
    required this.relations,
    required this.source,
  });

  final List<ExtractedConceptDraft> concepts;
  final List<ExtractedRelationDraft> relations;
  final String source; // ai | heuristic | cache
}

/// Extraction heuristique locale + parsing/validation des payloads IA.
class ConceptExtractionService {
  ConceptExtractionService({
    ConceptNormalizer normalizer = const ConceptNormalizer(),
    AiJsonParser parser = const AiJsonParser(),
  })  : _normalizer = normalizer,
        _parser = parser;

  final ConceptNormalizer _normalizer;
  final AiJsonParser _parser;

  ConceptExtractionResult extractHeuristic(Quiz quiz) {
    final concepts = <ExtractedConceptDraft>[];
    final seen = <String>{};

    void addConcept(String name, List<String> qIds, {String description = ''}) {
      final canon = _normalizer.canonicalize(name);
      if (canon.isEmpty || seen.contains(canon)) return;
      seen.add(canon);
      concepts.add(
        ExtractedConceptDraft(
          name: _normalizer.displayName(name),
          description: description,
          questionIds: qIds,
          skills: const [],
        ),
      );
    }

    if (quiz.subject.trim().isNotEmpty) {
      addConcept(quiz.subject, [for (final q in quiz.questions) q.id]);
    }

    for (final q in quiz.questions) {
      for (final seed in _tokensFromQuestion(q)) {
        addConcept(seed, [q.id], description: q.explanation);
      }
    }

    final relations = <ExtractedRelationDraft>[];
    if (concepts.length >= 2 && quiz.subject.trim().isNotEmpty) {
      final root = concepts.first.name;
      for (var i = 1; i < concepts.length; i++) {
        relations.add(
          ExtractedRelationDraft(
            from: root,
            to: concepts[i].name,
            type: 'related',
            justification: 'Heuristique : même quiz / matière.',
          ),
        );
      }
    }

    return ConceptExtractionResult(
      concepts: concepts,
      relations: relations,
      source: 'heuristic',
    );
  }

  List<String> _tokensFromQuestion(Question q) {
    final text = '${q.text} ${q.explanation}';
    final words = text
        .split(RegExp(r'[^A-Za-zÀ-ÿ0-9+\-]+'))
        .map((w) => w.trim())
        .where((w) => w.length >= 4)
        .toList();
    const stop = {
      'dans',
      'avec',
      'pour',
      'cette',
      'quel',
      'quelle',
      'quels',
      'quelles',
      'parmi',
      'suivant',
      'suivante',
      'permet',
      'permettent',
      'entre',
      'when',
      'what',
      'which',
      'that',
      'with',
      'from',
      'this',
      'have',
      'does',
    };
    final candidates = <String>[];
    for (final w in words) {
      final lower = w.toLowerCase();
      if (stop.contains(lower)) continue;
      if (RegExp(r'^[A-Z]').hasMatch(w) || lower.length >= 6) {
        candidates.add(_normalizer.displayName(w));
      }
    }
    final expl = q.explanation.split(RegExp(r'\s+'));
    for (var i = 0; i < expl.length - 1; i++) {
      final a = expl[i].replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
      final b = expl[i + 1].replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
      if (a.length >= 4 && b.length >= 4) {
        candidates.add(_normalizer.displayName('$a $b'));
      }
    }
    return candidates.take(3).toList();
  }

  ConceptExtractionResult parseAiPayload(String raw, Quiz quiz) {
    debugPrint(
      'KG extract: [parse] rawChars=${raw.length} '
      'preview=${_preview(raw)}',
    );

    final cleaned = stripLlmWrappers(raw);
    Map<String, dynamic> json;
    try {
      json = _parser.extractJsonObject(cleaned);
    } catch (_) {
      // JSON tronqué (maxTokens / EOS) : récupérer uniquement des concepts
      // complets déjà présents — sans inventer de noms.
      json = _recoverPartialConceptsJson(cleaned);
      debugPrint(
        'KG extract: [parse] partial recovery '
        'concepts=${(json['concepts'] as List?)?.length ?? 0}',
      );
    }

    final concepts = <ExtractedConceptDraft>[];
    final conceptsRaw = json['concepts'];
    if (conceptsRaw is List) {
      for (final item in conceptsRaw) {
        if (item is! Map) continue;
        if (concepts.length >= KgLlmConfig.maxConcepts) break;
        final name = item['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        if (isPlaceholderConceptName(
          name,
          questionIds: quiz.questions.map((q) => q.id),
        )) {
          continue;
        }
        final qIds = (item['questionIds'] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const [];
        final skills = (item['skills'] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList() ??
            const [];
        final validIds = qIds
            .where((id) => quiz.questions.any((q) => q.id == id))
            .toList();
        concepts.add(
          ExtractedConceptDraft(
            name: _normalizer.displayName(name),
            description: item['description']?.toString() ?? '',
            questionIds: validIds.isEmpty
                ? [for (final q in quiz.questions.take(1)) q.id]
                : validIds,
            skills: skills,
          ),
        );
      }
    }

    final relations = <ExtractedRelationDraft>[];
    final relRaw = json['relations'];
    if (relRaw is List) {
      final names = {for (final c in concepts) _normalizer.canonicalize(c.name)};
      for (final item in relRaw) {
        if (item is! Map) continue;
        if (relations.length >= KgLlmConfig.maxRelations) break;
        final from = item['from']?.toString().trim() ?? '';
        final to = item['to']?.toString().trim() ?? '';
        var type = item['type']?.toString().trim() ?? 'related';
        if (from.isEmpty || to.isEmpty) continue;
        if (isPlaceholderConceptName(
              from,
              questionIds: quiz.questions.map((q) => q.id),
            ) ||
            isPlaceholderConceptName(
              to,
              questionIds: quiz.questions.map((q) => q.id),
            )) {
          continue;
        }
        if (!names.contains(_normalizer.canonicalize(from)) ||
            !names.contains(_normalizer.canonicalize(to))) {
          continue;
        }
        if (type != 'prerequisite' &&
            type != 'related' &&
            type != 'part_of') {
          type = 'related';
        }
        relations.add(
          ExtractedRelationDraft(
            from: from,
            to: to,
            type: type,
            justification: item['justification']?.toString() ?? '',
          ),
        );
      }
    }

    if (concepts.isEmpty) {
      debugPrint('KG extract: [parse] FAIL aucun concept valide');
      throw QuizAiException(
        'Extraction IA : aucun concept valide.',
        code: 'invalid_json',
      );
    }

    debugPrint(
      'KG extract: [parse] OK concepts=${concepts.length} '
      'relations=${relations.length}',
    );

    return ConceptExtractionResult(
      concepts: concepts,
      relations: relations,
      source: 'ai',
    );
  }

  /// JSON normalisé pour le cache SQLite (relecture fiable).
  String encodeResultPayload(ConceptExtractionResult result) {
    return jsonEncode({
      'concepts': [
        for (final c in result.concepts)
          {
            'name': c.name,
            'description': c.description,
            'questionIds': c.questionIds,
            'skills': c.skills,
          },
      ],
      'relations': [
        for (final r in result.relations)
          {
            'from': r.from,
            'to': r.to,
            'type': r.type,
            'justification': r.justification,
          },
      ],
    });
  }

  /// Retire fences markdown, balises ChatML et texte hors objet JSON.
  @visibleForTesting
  static String stripLlmWrappers(String raw) {
    var t = raw.trim();
    // ChatML / tokens spéciaux parfois réémis.
    t = t.replaceAll(
      RegExp(r'<\|im_start\|>|<\|im_end\|>|<\|endoftext\|>'),
      '\n',
    );
    t = t.replaceAll(RegExp(r'```json', caseSensitive: false), '```');
    t = t.replaceAll('```', '\n');
    // Couper un éventuel préambule « Voici le JSON : »
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return t.substring(start, end + 1).trim();
    }
    if (start >= 0) {
      // Objet non fermé : garder depuis `{` pour recovery partielle.
      return t.substring(start).trim();
    }
    return t;
  }

  /// Extrait des objets concept complets dans un JSON tronqué.
  /// Ne crée aucun nom : uniquement ce qui est déjà dans le texte.
  static Map<String, dynamic> _recoverPartialConceptsJson(String cleaned) {
    final concepts = <Map<String, dynamic>>[];
    final conceptBlock = RegExp(
      r'\{\s*"name"\s*:\s*"([^"\\]|\\.)*"\s*(,\s*"[^"]+"\s*:\s*(\[[^\]]*\]|"([^"\\]|\\.)*"|[^,}\]]+))*\s*\}',
      multiLine: true,
    );
    for (final m in conceptBlock.allMatches(cleaned)) {
      try {
        final obj = jsonDecode(m.group(0)!);
        if (obj is Map<String, dynamic> &&
            (obj['name']?.toString().trim().isNotEmpty ?? false)) {
          concepts.add(obj);
        }
      } catch (_) {
        // objet incomplet → ignore
      }
      if (concepts.length >= KgLlmConfig.maxConcepts) break;
    }
    if (concepts.isEmpty) {
      throw QuizAiException(
        'Réponse IA JSON invalide ou incomplète.',
        code: 'invalid_json',
      );
    }
    return {'concepts': concepts, 'relations': <dynamic>[]};
  }

  static String _preview(String raw) {
    final t = raw.replaceAll('\n', ' ').trim();
    return t.length <= 120 ? t : '${t.substring(0, 120)}…';
  }

  /// Prompt utilisateur compact (le system ChatML est dans [KgLlmConfig]).
  String buildExtractionPrompt(Quiz quiz) {
    final qs = quiz.questions.take(KgLlmConfig.maxQuestionsInPrompt).toList();
    final idExample = qs.isEmpty ? 'q1' : qs.first.id;
    final subjectHint =
        quiz.subject.trim().isEmpty ? 'Informatique' : quiz.subject.trim();
    final questionLines = <String>[
      for (final q in qs)
        '- id=${q.id} | ${_truncate(q.text, 90)}'
            '${q.explanation.trim().isEmpty ? '' : ' | ${_truncate(q.explanation, 60)}'}',
    ];
    return '''
Matière: $subjectHint
Titre: ${quiz.title}
Questions:
${questionLines.join('\n')}

Règles STRICTES pour "name" :
- nom de notion pédagogique en français (ex: "Héritage", "Adresse IP", "Conteneur Docker")
- INTERDIT : id de question ($idExample, java-0, rest-0, docker-1…), variables, codes techniques

Exemple JSON valide (adapte les notions au quiz, garde la forme) :
{"concepts":[{"name":"Héritage","questionIds":["$idExample"]},{"name":"$subjectHint","questionIds":["$idExample"]}],"relations":[{"from":"Héritage","to":"$subjectHint","type":"part_of"}]}

Réponds UNIQUEMENT avec un objet JSON (max ${KgLlmConfig.maxConcepts} concepts, max ${KgLlmConfig.maxRelations} relations).
type ∈ related|prerequisite|part_of
''';
  }

  /// Seconde tentative : prompt encore plus court si la 1ère réponse
  /// ne contenait que des IDs / JSON inexploitable.
  String buildCorrectivePrompt(Quiz quiz) {
    final qs = quiz.questions.take(2).toList();
    final idExample = qs.isEmpty ? 'q1' : qs.first.id;
    final subject =
        quiz.subject.trim().isEmpty ? 'Cours' : quiz.subject.trim();
    final bullets = qs
        .map((q) => '- ${q.id}: ${_truncate(q.text, 70)}')
        .join('\n');
    return '''
Corrige : la réponse précédente était invalide (ids copiés ou JSON inutilisable).

Quiz "$subject". Questions:
$bullets

Écris UNIQUEMENT ce JSON avec de VRAIES notions (pas d'id comme java-0/rest-0) :
{"concepts":[{"name":"$subject","questionIds":["$idExample"]}],"relations":[]}
''';
  }

  /// true si [name] est un placeholder / id technique — jamais un concept.
  @visibleForTesting
  static bool isPlaceholderConceptName(
    String name, {
    Iterable<String> questionIds = const [],
  }) {
    final n = name.trim();
    if (n.isEmpty || n == '...' || n == '…') return true;
    final lower = n.toLowerCase();
    const banned = {
      'notion',
      'nomcourt',
      'concept',
      'name',
      'a',
      'b',
      'from',
      'to',
      'prerequisite',
      'part_of',
      'related',
    };
    if (banned.contains(lower)) return true;
    // Ids techniques du type docker-0 / rest-12 / java-0.
    if (RegExp(r'^[a-z][a-z0-9_]*-\d+$').hasMatch(lower)) return true;
    // Égalité exacte avec un id de question du quiz.
    for (final id in questionIds) {
      if (id.trim().isNotEmpty && lower == id.trim().toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  static String _truncate(String s, int max) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }
}
