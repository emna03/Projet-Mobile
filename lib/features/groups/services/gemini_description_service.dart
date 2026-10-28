import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/gemini_config.dart';

/// Writing style requested from the AI assistant.
enum DescriptionTone {
  professional('Professionnel', 'professionnel, clair et structuré'),
  friendly('Convivial', 'chaleureux, accueillant et convivial'),
  motivating('Motivant', 'dynamique, motivant et engageant');

  const DescriptionTone(this.label, this.promptHint);
  final String label;
  final String promptHint;
}

/// Error raised by [GeminiDescriptionService] with a user-facing French
/// message.
class GeminiException implements Exception {
  final String message;
  const GeminiException(this.message);

  @override
  String toString() => message;
}

/// Internal wrapper marking a failure another model might not have.
class _RetryableGeminiError implements Exception {
  final GeminiException error;
  const _RetryableGeminiError(this.error);
}

/// Thin REST client around the Google Gemini `generateContent` endpoint,
/// specialised for writing study-group descriptions.
///
/// The API key is never hard-coded: it comes from [GeminiConfig]
/// (`--dart-define` or the gitignored `assets/config/gemini_config.json`).
///
/// Gemini models are regularly overloaded (HTTP 503), rate-limited (429) or
/// retired (404). Requests therefore try the configured model first, then
/// each of [defaultFallbackModels] until one answers.
class GeminiDescriptionService {
  GeminiDescriptionService({
    http.Client? client,
    String? apiKey,
    String? model,
    List<String>? fallbackModels,
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey ?? GeminiConfig.apiKey,
        _models = {
          model ?? GeminiConfig.model,
          ...(fallbackModels ?? defaultFallbackModels),
        }.where((m) => m.isNotEmpty).toList();

  final http.Client _client;
  final String _apiKey;
  final List<String> _models;
  String? _lastModelUsed;

  /// Tried in order after the configured model. Flash models answer in a
  /// few seconds with minimal thinking; "lite" ones are slower but rarely
  /// overloaded.
  static const defaultFallbackModels = [
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-flash-lite-latest',
    'gemini-flash-latest',
  ];

  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const _attemptTimeout = Duration(seconds: 30);
  static const _totalBudget = Duration(seconds: 75);

  /// Model that produced the last successful answer.
  String? get lastModelUsed => _lastModelUsed;

  /// Must match `FormValidators.validateGroupDescription`.
  static const int maxLength = 300;
  static const int minLength = 10;

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Writes a brand-new description from the group's metadata.
  Future<String> generateDescription({
    required String groupName,
    required String level,
    required bool isPublic,
    String keywords = '',
    DescriptionTone tone = DescriptionTone.professional,
  }) {
    final prompt = StringBuffer()
      ..writeln("Rédige la description d'un groupe d'étude universitaire "
          "pour l'application StudyMate.")
      ..writeln('- Nom du groupe : $groupName')
      ..writeln('- Niveau académique : $level')
      ..writeln('- Type : ${isPublic ? 'public (ouvert à tous)' : 'privé (sur demande)'}');
    if (keywords.trim().isNotEmpty) {
      prompt.writeln('- Sujets / mots-clés à couvrir : ${keywords.trim()}');
    }
    prompt
      ..writeln()
      ..write(_rules(tone));
    return _generate(prompt.toString());
  }

  /// Rewrites an existing description to make it clearer and more engaging.
  Future<String> improveDescription({
    required String groupName,
    required String level,
    required String currentDescription,
    DescriptionTone tone = DescriptionTone.professional,
  }) {
    final prompt = StringBuffer()
      ..writeln("Améliore la description suivante d'un groupe d'étude "
          "universitaire (application StudyMate). Conserve le sens et les "
          "informations, corrige l'orthographe, rends-la plus claire et "
          "plus attractive.")
      ..writeln('- Nom du groupe : $groupName')
      ..writeln('- Niveau académique : $level')
      ..writeln('- Description actuelle : """${currentDescription.trim()}"""')
      ..writeln()
      ..write(_rules(tone));
    return _generate(prompt.toString());
  }

  String _rules(DescriptionTone tone) => '''
Contraintes :
- Rédige en français, avec un ton ${tone.promptHint}.
- 2 à 3 phrases, entre 120 et 260 caractères au total (maximum absolu : $maxLength caractères).
- Mentionne les objectifs du groupe et ce que les membres vont y faire.
- Pas de titre, pas de markdown, pas de guillemets, pas de liste à puces, pas d'emoji.
- Réponds uniquement avec la description, sans aucun commentaire.''';

  Future<String> _generate(String prompt) async {
    if (!isConfigured) {
      throw const GeminiException(
        'Clé API Gemini manquante. Renseignez-la dans '
        '${GeminiConfig.assetPath} puis relancez complètement l\'application.',
      );
    }

    final stopwatch = Stopwatch()..start();
    GeminiException? lastError;

    for (final model in _models) {
      if (stopwatch.elapsed > _totalBudget) break;
      try {
        final text = await _generateWith(model, prompt);
        _lastModelUsed = model;
        return text;
      } on _RetryableGeminiError catch (e) {
        lastError = e.error; // try the next model
      }
    }

    throw lastError ??
        const GeminiException(
            'Le service Gemini est momentanément indisponible. Réessayez.');
  }

  /// One attempt on [model]. Throws [_RetryableGeminiError] when another
  /// model may succeed, or [GeminiException] when retrying is pointless
  /// (invalid key, no network, blocked content).
  Future<String> _generateWith(
    String model,
    String prompt, {
    bool withThinkingConfig = true,
  }) async {
    final uri = Uri.parse('$_baseUrl/$model:generateContent');
    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ],
        }
      ],
      'generationConfig': {
        'temperature': 0.8,
        'maxOutputTokens': 1024,
        // Short creative text: deep reasoning only adds latency.
        if (withThinkingConfig) 'thinkingConfig': {'thinkingLevel': 'minimal'},
      },
    });

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: body,
          )
          .timeout(_attemptTimeout);
    } on TimeoutException {
      throw const _RetryableGeminiError(GeminiException(
          'Le service IA met trop de temps à répondre. Réessayez.'));
    } on SocketException {
      throw const GeminiException(
          'Pas de connexion Internet. Vérifiez votre réseau.');
    } on http.ClientException {
      throw const GeminiException(
          'Impossible de contacter le service IA. Vérifiez votre réseau.');
    }

    final code = response.statusCode;
    if (code == 400 &&
        withThinkingConfig &&
        response.body.toLowerCase().contains('thinking')) {
      // Older models reject `thinkingLevel`: retry the same model without it.
      return _generateWith(model, prompt, withThinkingConfig: false);
    }
    if (code == 404 || code == 429 || code >= 500) {
      throw _RetryableGeminiError(
          GeminiException(_messageForStatus(code, model)));
    }
    if (code != 200) {
      throw GeminiException(_messageForStatus(code, model));
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw const GeminiException('Réponse du service IA illisible.');
    }

    if (json['promptFeedback']?['blockReason'] != null) {
      throw const GeminiException(
          'La demande a été bloquée par les filtres de sécurité. '
          'Modifiez le nom ou les mots-clés.');
    }

    final candidates = json['candidates'] as List?;
    final parts = (candidates?.isNotEmpty ?? false)
        ? (candidates!.first['content']?['parts'] as List?)
        : null;
    final text = parts
            ?.map((p) => p['text'])
            .whereType<String>()
            .join()
            .trim() ??
        '';

    if (text.isEmpty) {
      throw const _RetryableGeminiError(GeminiException(
          "L'IA n'a renvoyé aucune description. Réessayez."));
    }

    final cleaned = _sanitize(text);
    if (cleaned.length < minLength) {
      throw const _RetryableGeminiError(GeminiException(
          'La description générée est trop courte. Réessayez.'));
    }
    return cleaned;
  }

  String _messageForStatus(int code, String model) => switch (code) {
        400 => 'Requête refusée par Gemini (clé API ou paramètres invalides).',
        401 || 403 => 'Clé API Gemini invalide ou non autorisée.',
        404 => 'Modèle Gemini « $model » introuvable.',
        429 => 'Quota Gemini atteint. Patientez quelques instants.',
        >= 500 => 'Le service Gemini est momentanément surchargé. '
            'Réessayez dans un instant.',
        _ => 'Erreur inattendue du service IA (code $code).',
      };

  /// Removes markdown/quotes and enforces the app's 300-character limit,
  /// preferably cutting at a sentence boundary.
  static String _sanitize(String raw) {
    var text = raw
        .replaceAll(RegExp(r'[*_#`]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    text = text.replaceAll(RegExp(r'^["«“\s]+|["»”\s]+$'), '').trim();

    if (text.length <= maxLength) return text;

    final cut = text.substring(0, maxLength);
    final lastSentence = cut.lastIndexOf(RegExp(r'[.!?]'));
    if (lastSentence >= minLength) return cut.substring(0, lastSentence + 1);
    final lastSpace = cut.lastIndexOf(' ');
    final end = lastSpace > 0 ? lastSpace : maxLength - 1;
    return '${cut.substring(0, end).trimRight()}…';
  }

  void dispose() => _client.close();
}
