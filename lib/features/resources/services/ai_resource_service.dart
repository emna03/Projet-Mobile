import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/gemini_config.dart';
import '../../../core/utils/pdf_storage.dart';
import '../models/resource.dart';
import 'course_text.dart';

class AiException implements Exception {
  AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Résumé et flashcards via l'API Google Gemini, à partir du cours (texte ou fichier).
class AiResourceService {
  Future<String> summarize(Resource resource) async {
    _requireKey();
    final doc = await _document(resource);
    final text = await _ask(
      _summaryPrompt(resource, doc),
      systemInstruction: _summarySystem,
      inlineBytes: doc.pdfBytes,
      inlineMime: doc.pdfMime,
    );
    if (text == null || text.trim().isEmpty) {
      throw AiException('Gemini n’a pas pu générer le résumé. Réessayez dans un instant.');
    }
    return _stripLatex(text.trim());
  }

  Future<List<Flashcard>> flashcards(Resource resource) async {
    final id = resource.id;
    if (id == null) return const [];
    _requireKey();
    final doc = await _document(resource);
    final text = await _ask(
      _flashcardPrompt(resource, doc),
      systemInstruction: _flashcardSystem,
      generationConfig: _flashcardGenConfig,
      inlineBytes: doc.pdfBytes,
      inlineMime: doc.pdfMime,
    );
    final cards = _parseFlashcards(text, id);
    if (cards.isEmpty) {
      throw AiException('Gemini n’a pas pu générer les flashcards. Réessayez dans un instant.');
    }
    return cards;
  }

  void _requireKey() {
    if (!GeminiConfig.isEnabled) {
      throw AiException('Ajoutez une clé API Gemini pour générer le résumé et les flashcards.');
    }
  }

  // ───────────────────────── Document ─────────────────────────

  Future<({String text, Uint8List? pdfBytes, String? pdfMime})> _document(Resource resource) async {
    var bytes = resource.pdfBytes;
    if ((bytes == null || bytes.isEmpty) && resource.pdfPath != null) {
      bytes = await PdfStorage.readBytes(resource.pdfPath);
    }
    final buffer = StringBuffer(resource.content.trim());
    Uint8List? pdfBytes;
    String? pdfMime;

    if (bytes != null && bytes.isNotEmpty) {
      switch (resource.attachedKind) {
        case ResourceFileKind.pdf:
          pdfBytes = bytes;
          pdfMime = 'application/pdf';
        case ResourceFileKind.powerpoint:
          final extracted = CourseText.fromPptx(bytes);
          if (extracted.trim().isNotEmpty) {
            if (buffer.isNotEmpty) buffer.writeln();
            buffer.write(extracted);
          } else {
            pdfBytes = bytes;
            pdfMime = resource.attachedMimeType;
          }
        case ResourceFileKind.other:
          break;
      }
    }
    return (text: buffer.toString().trim(), pdfBytes: pdfBytes, pdfMime: pdfMime);
  }

  // ───────────────────────── Prompts ─────────────────────────

  static const _summarySystem = '''
Tu es un enseignant qui rédige des résumés de révision.
- Résume uniquement le cours fourni (texte et/ou document joint). N'invente rien.
- Va de l'essentiel au secondaire : définitions, règles et formules clés, puis exemples.
- Garde les formules exactes et mentionne les conditions importantes (ex. n ≠ -1).
- Texte continu, sans titre ni puces.
- N'utilise JAMAIS de LaTeX ni de symbole \$ : maths en Unicode (x², x³, ×, √, x^(n+1)/(n+1)).
- Réponds dans la langue du cours.
''';

  static const _flashcardSystem = '''
Tu es un enseignant expert qui crée des flashcards de révision de haute qualité.

RÈGLES DE CONTENU
- Base-toi uniquement sur le cours fourni (texte et/ou document joint). N'invente aucune information fausse.
- Une flashcard = une seule idée testable. Question courte et sans ambiguïté, réponse précise (1 à 2 phrases maximum).
- Varie les types : définition, formule ou règle, exemple calculé, "pourquoi" / compréhension, application, piège fréquent.
- Évite les questions oui/non. Pas de doublons. Ne répète pas la réponse dans la question.
- La question doit être compréhensible seule, sans voir le cours.

RÈGLES DE FORME
- Écris dans la langue du cours.
- N'utilise JAMAIS de LaTeX ni de symbole \$. Maths en Unicode : x², x³, ×, ÷, √, x^(n+1)/(n+1).
- Réponds uniquement avec du JSON valide, sans texte autour ni balises markdown.
''';

  String _summaryPrompt(Resource r, ({String text, Uint8List? pdfBytes, String? pdfMime}) doc) {
    final hasDoc = doc.pdfBytes != null || doc.text.isNotEmpty;
    return '''
Rédige un résumé de révision clair (4 à 8 phrases) du cours.
${doc.pdfBytes != null ? 'Lis le document PDF joint et résume son contenu réel.' : ''}
${hasDoc ? '' : 'Aucun document : base-toi sur le titre et la matière sans inventer de détails faux.'}

Titre : ${r.title}
Matière : ${r.subject}
${doc.text.isEmpty ? '' : 'Contenu :\n${doc.text}'}
''';
  }

  String _flashcardPrompt(Resource r, ({String text, Uint8List? pdfBytes, String? pdfMime}) doc) {
    return '''
Crée 6 à 10 flashcards à partir du cours.
${doc.pdfBytes != null ? 'Lis le document PDF joint et crée les questions à partir de son contenu réel.' : ''}
Format : [{"question": "...", "answer": "..."}]

Titre : ${r.title}
Matière : ${r.subject}
${doc.text.isEmpty ? '' : '\nCOURS :\n${doc.text}'}
''';
  }

  static const Map<String, Object?> _flashcardGenConfig = {
    'temperature': 0.3,
    'maxOutputTokens': 4096,
    'responseMimeType': 'application/json',
    'responseSchema': {
      'type': 'ARRAY',
      'items': {
        'type': 'OBJECT',
        'properties': {
          'question': {'type': 'STRING'},
          'answer': {'type': 'STRING'},
        },
        'required': ['question', 'answer'],
      },
    },
  };

  static const Map<String, Object?> _defaultGenConfig = {
    'temperature': 0.4,
    'maxOutputTokens': 4096,
  };

  // ───────────────────────── HTTP ─────────────────────────

  static const _retry = Object();
  static const _unusable = Object();

  Future<String?> _ask(
    String prompt, {
    String? systemInstruction,
    Map<String, Object?>? generationConfig,
    Uint8List? inlineBytes,
    String? inlineMime,
  }) async {
    final skipped = <String>{};
    for (var pass = 0; pass < 3; pass++) {
      for (final model in GeminiConfig.models) {
        if (skipped.contains(model)) continue;
        final result = await _askOnce(
          prompt,
          model,
          systemInstruction: systemInstruction,
          generationConfig: generationConfig,
          inlineBytes: inlineBytes,
          inlineMime: inlineMime,
        );
        if (result is String) return result;
        if (result == null) return null;
        if (result == _unusable) skipped.add(model);
      }
      if (skipped.length == GeminiConfig.models.length) break;
      await Future<void>.delayed(Duration(seconds: 2 + pass * 3));
    }
    return null;
  }

  Future<Object?> _askOnce(
    String prompt,
    String model, {
    String? systemInstruction,
    Map<String, Object?>? generationConfig,
    Uint8List? inlineBytes,
    String? inlineMime,
  }) async {
    try {
      final parts = <Map<String, Object?>>[
        if (inlineBytes != null && inlineMime != null)
          {
            'inline_data': {
              'mime_type': inlineMime,
              'data': base64Encode(inlineBytes),
            },
          },
        {'text': prompt},
      ];
      final uri = Uri.parse('${GeminiConfig.endpoint}/$model:generateContent');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': GeminiConfig.apiKey,
            },
            body: jsonEncode({
              'contents': [
                {'parts': parts}
              ],
              if (systemInstruction != null)
                'systemInstruction': {
                  'parts': [
                    {'text': systemInstruction}
                  ]
                },
              'generationConfig': generationConfig ?? _defaultGenConfig,
            }),
          )
          .timeout(const Duration(seconds: 90));

      final code = response.statusCode;
      if (code == 500 || code == 503 || code == 504) {
        debugPrint('Gemini $code on $model, trying next...');
        return _retry;
      }
      if (code == 400 || code == 404 || code == 429) {
        debugPrint('Gemini $code on $model (unusable): ${response.body}');
        return _unusable;
      }
      if (code != 200) {
        debugPrint('Gemini $code: ${response.body}');
        return null;
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes));
      final partsOut = (json['candidates'] as List?)?.firstOrNull?['content']?['parts'] as List?;
      final texts = partsOut
          ?.map((p) => (p as Map)['text'] as String? ?? '')
          .where((t) => t.isNotEmpty)
          .join('\n');
      if (texts == null || texts.isEmpty) {
        debugPrint('Gemini $model: empty response, trying next...');
        return _retry;
      }
      return texts;
    } catch (e) {
      debugPrint('Gemini request failed on $model: $e');
      return _retry;
    }
  }

  String _stripLatex(String s) => s
      .replaceAll(r'\cdot', '×')
      .replaceAll(r'\times', '×')
      .replaceAllMapped(RegExp(r'\\frac\{([^}]*)\}\{([^}]*)\}'), (m) => '(${m[1]})/(${m[2]})')
      .replaceAll(r'$', '')
      .replaceAll(r'\(', '')
      .replaceAll(r'\)', '');

  List<Flashcard> _parseFlashcards(String? raw, int resourceId) {
    if (raw == null) return const [];
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceAll(RegExp(r'^```(json)?\s*', multiLine: true), '')
          .replaceAll(RegExp(r'\s*```$'), '');
    }
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start == -1 || end <= start) return const [];
    try {
      final list = jsonDecode(text.substring(start, end + 1));
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => Flashcard(
                resourceId: resourceId,
                question: _stripLatex('${e['question'] ?? ''}'.trim()),
                answer: _stripLatex('${e['answer'] ?? ''}'.trim()),
              ))
          .where((c) => c.question.isNotEmpty && c.answer.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Flashcards JSON parse failed: $e');
      return const [];
    }
  }
}
