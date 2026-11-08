import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/ai_analysis.dart';
import '../models/quiz.dart';
import '../models/quiz_attempt.dart';
import 'ai_json_parser.dart';
import 'quiz_ai_provider.dart';

/// Configuration OpenRouter (jamais de clé hardcodée).
///
/// Production :
/// `--dart-define=OPENROUTER_PROXY_URL=https://...cloudfunctions.net/openRouterProxy`
///
/// Démo locale uniquement :
/// `--dart-define=OPENROUTER_API_KEY=...`
///
/// Modèle free par défaut (surchargeable) :
/// `--dart-define=OPENROUTER_MODEL=google/gemma-4-31b-it:free`
class OpenRouterConfig {
  OpenRouterConfig({
    String? proxyUrl,
    String? apiKey,
    String? model,
    this.authTokenProvider,
  })  : proxyUrl =
            proxyUrl ?? const String.fromEnvironment('OPENROUTER_PROXY_URL'),
        apiKey = apiKey ?? const String.fromEnvironment('OPENROUTER_API_KEY'),
        model = model ??
            const String.fromEnvironment(
              'OPENROUTER_MODEL',
              defaultValue: 'google/gemma-4-31b-it:free',
            );

  final String proxyUrl;
  final String apiKey;
  final String model;
  final Future<String?> Function()? authTokenProvider;

  bool get hasProxy => proxyUrl.trim().isNotEmpty;
  bool get hasApiKey => apiKey.trim().isNotEmpty;
  bool get isConfigured => hasProxy || hasApiKey;
}

class OpenRouterService implements QuizAiProvider {
  OpenRouterService({
    OpenRouterConfig? config,
    http.Client? client,
    Duration timeout = const Duration(seconds: 60),
    AiJsonParser parser = const AiJsonParser(),
  })  : _config = config ?? OpenRouterConfig(),
        _client = client ?? http.Client(),
        _timeout = timeout,
        _parser = parser;

  OpenRouterConfig _config;
  final http.Client _client;
  final Duration _timeout;
  final AiJsonParser _parser;

  /// Remplace la config effective (ex. après chargement du stockage sécurisé).
  void reconfigure(OpenRouterConfig config) {
    _config = config;
  }

  OpenRouterConfig get config => _config;

  @override
  String get displayName => 'OpenRouter';

  @override
  AiProviderKind get kind => AiProviderKind.openRouter;

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
      throw QuizAiException(
        'Le sujet du cours est obligatoire.',
        code: 'validation',
        provider: displayName,
      );
    }
    final count = questionCount.clamp(5, 15);
    final prompt = _parser.buildGeneratePrompt(
      topic: cleanedTopic,
      difficulty: difficulty,
      count: count,
    );
    final raw = await _generateText(prompt);
    final json = _parser.extractJsonObject(raw);
    return _parser.quizFromGeneratedJson(
      json,
      difficulty: difficulty,
      topic: cleanedTopic,
      generatedByLabel: 'OpenRouter',
    );
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
      final selected =
          i < attempt.selectedAnswers.length ? attempt.selectedAnswers[i] : null;
      if (selected != q.correctIndex) {
        wrong.add({
          'question': q.text,
          'selected': selected == null ||
                  selected < 0 ||
                  selected >= q.options.length
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
    final json = _parser.extractJsonObject(raw);
    return AiAnalysis.fromJson(json);
  }

  Future<String> _generateText(String prompt) async {
    if (!_config.isConfigured) {
      throw QuizAiException(
        'La génération intelligente n’est pas encore activée sur cet appareil.',
        code: 'not_configured',
        provider: displayName,
      );
    }

    try {
      if (_config.hasProxy) {
        return await _callProxy(prompt);
      }
      return await _callOpenRouterApi(prompt);
    } on QuizAiException {
      rethrow;
    } on TimeoutException {
      throw QuizAiException(
        'Délai dépassé lors de l’appel OpenRouter.',
        code: 'timeout',
        provider: displayName,
      );
    } on SocketException catch (e) {
      throw QuizAiException(
        'Impossible de joindre OpenRouter : ${e.message}',
        code: 'network',
        provider: displayName,
      );
    } on http.ClientException catch (e) {
      throw QuizAiException(
        'Impossible de joindre OpenRouter : ${e.message}',
        code: 'network',
        provider: displayName,
      );
    }
  }

  Future<String> _callProxy(String prompt) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
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

    return _readProxyOrChatText(response);
  }

  Future<String> _callOpenRouterApi(String prompt) async {
    final response = await _client
        .post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${_config.apiKey}',
            'HTTP-Referer': 'https://studymate.local',
            'X-Title': 'StudyMate Quiz',
          },
          body: jsonEncode({
            'model': _config.model,
            'temperature': 0.4,
            'messages': [
              {
                'role': 'user',
                'content': prompt,
              },
            ],
          }),
        )
        .timeout(_timeout);

    return _readProxyOrChatText(response);
  }

  String _readProxyOrChatText(http.Response response) {
    if (response.statusCode == 429) {
      throw QuizAiException(
        'Quota OpenRouter dépassé. Réessayez plus tard.',
        code: 'quota',
        provider: displayName,
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw QuizAiException(
        'OpenRouter : accès refusé (${response.statusCode}).',
        code: 'unavailable',
        provider: displayName,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw QuizAiException(
        'OpenRouter indisponible : HTTP ${response.statusCode}',
        code: 'unavailable',
        provider: displayName,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      if (decoded['text'] is String &&
          (decoded['text'] as String).trim().isNotEmpty) {
        return decoded['text'] as String;
      }
      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final message = choices.first['message'];
        if (message is Map) {
          final content = message['content']?.toString();
          if (content != null && content.trim().isNotEmpty) {
            return content;
          }
        }
      }
    }
    throw QuizAiException(
      'Réponse OpenRouter vide ou invalide.',
      code: 'invalid_json',
      provider: displayName,
    );
  }

  @override
  void dispose() {
    _client.close();
  }
}
