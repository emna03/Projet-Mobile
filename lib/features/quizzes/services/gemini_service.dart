import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/ai_analysis.dart';
import '../models/quiz.dart';
import '../models/quiz_attempt.dart';
import 'ai_json_parser.dart';
import 'gemini_exceptions.dart';
import 'quiz_ai_provider.dart';

/// Configuration runtime (jamais de clé hardcodée dans le dépôt).
///
/// Production recommandée :
/// `--dart-define=GEMINI_PROXY_URL=https://...cloudfunctions.net/geminiProxy`
///
/// Démo locale uniquement (clé visible dans le binaire) :
/// `--dart-define=GEMINI_API_KEY=...`
class GeminiConfig {
  GeminiConfig({
    String? proxyUrl,
    String? apiKey,
    String? model,
    this.authTokenProvider,
  })  : proxyUrl = proxyUrl ?? const String.fromEnvironment('GEMINI_PROXY_URL'),
        apiKey = apiKey ?? const String.fromEnvironment('GEMINI_API_KEY'),
        model = model ??
            const String.fromEnvironment(
              'GEMINI_MODEL',
              defaultValue: 'gemini-flash-lite-latest',
            );

  final String proxyUrl;
  final String apiKey;
  final String model;
  final Future<String?> Function()? authTokenProvider;

  bool get hasProxy => proxyUrl.trim().isNotEmpty;
  bool get hasApiKey => apiKey.trim().isNotEmpty;
  bool get isConfigured => hasProxy || hasApiKey;
}

/// Couche service Gemini — conserve toutes les fonctionnalités existantes.
class GeminiService implements QuizAiProvider {
  GeminiService({
    GeminiConfig? config,
    http.Client? client,
    Duration timeout = const Duration(seconds: 45),
    AiJsonParser parser = const AiJsonParser(),
  })  : _config = config ?? GeminiConfig(),
        _client = client ?? http.Client(),
        _timeout = timeout,
        _parser = parser;

  GeminiConfig _config;
  final http.Client _client;
  final Duration _timeout;
  final AiJsonParser _parser;

  /// Remplace la config effective (ex. après chargement du stockage sécurisé).
  void reconfigure(GeminiConfig config) {
    _config = config;
  }

  GeminiConfig get config => _config;

  @override
  String get displayName => 'Gemini';

  @override
  AiProviderKind get kind => AiProviderKind.gemini;

  @override
  bool get isConfigured => _config.isConfigured;

  @override
  Future<Quiz> generateQuiz({
    required String topic,
    required QuizDifficulty difficulty,
    required int questionCount,
  }) async {
    final cleanedTopic = topic.trim();
    if (cleanedTopic.isEmpty) {
      throw GeminiException('Le sujet du cours est obligatoire.', code: 'validation');
    }
    final count = questionCount.clamp(5, 15);
    final prompt = _parser.buildGeneratePrompt(
      topic: cleanedTopic,
      difficulty: difficulty,
      count: count,
    );

    final raw = await _generateText(prompt);
    try {
      final json = _parser.extractJsonObject(raw);
      return _parser.quizFromGeneratedJson(
        json,
        difficulty: difficulty,
        topic: cleanedTopic,
        generatedByLabel: 'Gemini',
      );
    } on QuizAiException catch (e) {
      throw GeminiInvalidJsonException(e.message);
    }
  }

  @override
  Future<String> completeText(String prompt) => _generateText(prompt);

  @override
  Future<AiAnalysis> analyzeAttempt({
    required Quiz quiz,
    required QuizAttempt attempt,
  }) async {
    final wrong = <Map<String, dynamic>>[];
    for (var i = 0; i < quiz.questions.length; i++) {
      final q = quiz.questions[i];
      final selected = i < attempt.selectedAnswers.length ? attempt.selectedAnswers[i] : null;
      if (selected != q.correctIndex) {
        wrong.add({
          'question': q.text,
          'selected': selected == null || selected < 0 || selected >= q.options.length
              ? null
              : q.options[selected],
          'correct': q.options[q.correctIndex],
          'explanation': q.explanation,
        });
      }
    }

    final prompt = _parser.buildAnalyzePrompt(
      quiz: quiz,
      correctCount: attempt.correctCount,
      totalCount: attempt.totalCount,
      scorePercent: attempt.scorePercent,
      wrong: wrong,
    );

    final raw = await _generateText(prompt);
    try {
      final json = _parser.extractJsonObject(raw);
      return AiAnalysis.fromJson(json);
    } on QuizAiException catch (e) {
      throw GeminiInvalidJsonException(e.message);
    }
  }

  Future<String> _generateText(String prompt) async {
    if (!_config.isConfigured) {
      throw GeminiNotConfiguredException();
    }

    try {
      if (_config.hasProxy) {
        return await _callProxy(prompt);
      }
      return await _callGoogleApi(prompt);
    } on GeminiException {
      rethrow;
    } on TimeoutException {
      throw GeminiTimeoutException();
    } on SocketException catch (e) {
      throw GeminiNetworkException(e.message);
    } on http.ClientException catch (e) {
      throw GeminiNetworkException(e.message);
    }
  }

  Future<String> _callProxy(String prompt) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final token = await _config.authTokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _client
        .post(
          Uri.parse(_config.proxyUrl),
          headers: headers,
          body: jsonEncode({'prompt': prompt, 'model': _config.model}),
        )
        .timeout(_timeout);

    return _readModelText(response);
  }

  Future<String> _callGoogleApi(String prompt) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '${_config.model}:generateContent?key=${_config.apiKey}',
    );
    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0.4,
              'responseMimeType': 'application/json',
            },
          }),
        )
        .timeout(_timeout);

    return _readModelText(response);
  }

  String _readModelText(http.Response response) {
    if (response.statusCode == 429) {
      throw GeminiQuotaException();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw GeminiUnavailableException('accès refusé (${response.statusCode})');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GeminiUnavailableException('HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      if (decoded['text'] is String) {
        return decoded['text'] as String;
      }
      final candidates = decoded['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final content = candidates.first['content'];
        final parts = content is Map ? content['parts'] : null;
        if (parts is List && parts.isNotEmpty) {
          final text = parts.first['text']?.toString();
          if (text != null && text.trim().isNotEmpty) {
            return text;
          }
        }
      }
    }
    throw GeminiInvalidJsonException('texte modèle manquant');
  }

  @override
  void dispose() {
    _client.close();
  }
}
