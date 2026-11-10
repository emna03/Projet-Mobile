import 'dart:io' show Platform;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Credentials IA résolus pour le module Quiz.
///
/// Priorité : valeurs compile-time (`--dart-define`) > stockage sécurisé local.
/// Une chaîne vide n’est **jamais** considérée comme configurée.
class QuizAiResolvedCredentials {
  const QuizAiResolvedCredentials({
    required this.geminiApiKey,
    required this.geminiProxyUrl,
    required this.geminiModel,
    required this.openRouterApiKey,
    required this.openRouterProxyUrl,
    required this.openRouterModel,
  });

  final String geminiApiKey;
  final String geminiProxyUrl;
  final String geminiModel;
  final String openRouterApiKey;
  final String openRouterProxyUrl;
  final String openRouterModel;

  static const empty = QuizAiResolvedCredentials(
    geminiApiKey: '',
    geminiProxyUrl: '',
    geminiModel: '',
    openRouterApiKey: '',
    openRouterProxyUrl: '',
    openRouterModel: '',
  );

  /// Lecture pure des `--dart-define` (jamais loguée).
  factory QuizAiResolvedCredentials.fromEnvironment() {
    return const QuizAiResolvedCredentials(
      geminiApiKey: String.fromEnvironment('GEMINI_API_KEY'),
      geminiProxyUrl: String.fromEnvironment('GEMINI_PROXY_URL'),
      geminiModel: String.fromEnvironment(
        'GEMINI_MODEL',
        defaultValue: 'gemini-flash-lite-latest',
      ),
      openRouterApiKey: String.fromEnvironment('OPENROUTER_API_KEY'),
      openRouterProxyUrl: String.fromEnvironment('OPENROUTER_PROXY_URL'),
      openRouterModel: String.fromEnvironment(
        'OPENROUTER_MODEL',
        defaultValue: 'google/gemma-4-31b-it:free',
      ),
    );
  }

  bool get geminiConfigured =>
      geminiProxyUrl.trim().isNotEmpty || geminiApiKey.trim().isNotEmpty;

  bool get openRouterConfigured =>
      openRouterProxyUrl.trim().isNotEmpty || openRouterApiKey.trim().isNotEmpty;
}

/// Abstraction du coffre (tests mémoire / FlutterSecureStorage en prod).
abstract class QuizAiSecureVault {
  Future<Map<String, String>> readAll();
  Future<void> write({required String key, required String value});
}

class FlutterQuizAiSecureVault implements QuizAiSecureVault {
  FlutterQuizAiSecureVault([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }
}

/// Persiste les clés injectées une fois via `--dart-define` pour les prochains
/// lancements IDE/APK **sans** redéfinir les flags (données appareil uniquement).
///
/// N’écrit jamais les secrets dans les logs.
class QuizAiCredentialStore {
  QuizAiCredentialStore({QuizAiSecureVault? vault})
      : _vault = vault ?? FlutterQuizAiSecureVault();

  static const _kGeminiKey = 'quiz_ai.gemini.api_key';
  static const _kGeminiProxy = 'quiz_ai.gemini.proxy_url';
  static const _kGeminiModel = 'quiz_ai.gemini.model';
  static const _kOpenRouterKey = 'quiz_ai.openrouter.api_key';
  static const _kOpenRouterProxy = 'quiz_ai.openrouter.proxy_url';
  static const _kOpenRouterModel = 'quiz_ai.openrouter.model';

  final QuizAiSecureVault _vault;

  /// Fusionne dart-define et stockage local ; persiste les defines non vides.
  Future<QuizAiResolvedCredentials> resolveAndMaybePersist({
    QuizAiResolvedCredentials? compileOverride,
    bool persist = true,
  }) async {
    final compile = _normalize(
      compileOverride ?? QuizAiResolvedCredentials.fromEnvironment(),
    );

    if (_isFlutterTest && compileOverride == null) {
      return compile;
    }

    QuizAiResolvedCredentials stored = QuizAiResolvedCredentials.empty;
    try {
      stored = _normalize(await _readStored());
    } catch (_) {
      stored = QuizAiResolvedCredentials.empty;
    }

    final merged = QuizAiResolvedCredentials(
      geminiApiKey: _prefer(compile.geminiApiKey, stored.geminiApiKey),
      geminiProxyUrl: _prefer(compile.geminiProxyUrl, stored.geminiProxyUrl),
      geminiModel: _prefer(compile.geminiModel, stored.geminiModel),
      openRouterApiKey:
          _prefer(compile.openRouterApiKey, stored.openRouterApiKey),
      openRouterProxyUrl:
          _prefer(compile.openRouterProxyUrl, stored.openRouterProxyUrl),
      openRouterModel: _prefer(compile.openRouterModel, stored.openRouterModel),
    );

    if (persist && _hasPersistableCompileSecrets(compile)) {
      try {
        await _persistNonEmpty(compile);
      } catch (_) {
        // Stockage indisponible : on garde quand même les defines du build.
      }
    }

    return merged;
  }

  /// Enregistre une clé **uniquement si** le coffre n’en a pas déjà une.
  /// Retourne `true` si une clé non vide est désormais présente (déjà là ou ajoutée).
  Future<bool> saveKeyIfAbsent({
    required bool gemini,
    required String raw,
  }) async {
    final token = extractApiToken(raw, gemini: gemini);
    if (token == null || token.isEmpty) return false;

    try {
      final key = gemini ? _kGeminiKey : _kOpenRouterKey;
      final existing = (await _vault.readAll())[key]?.trim() ?? '';
      if (existing.isNotEmpty) {
        return true; // ne remplace pas
      }
      await _vault.write(key: key, value: token);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Extrait un token API depuis un collage brut (jamais logué).
  static String? extractApiToken(String raw, {required bool gemini}) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final m = RegExp(
      r'AIza[0-9A-Za-z_-]{20,}|AQ\.[0-9A-Za-z_-]{20,}|sk-or-v1-[0-9A-Za-z_-]{20,}',
    ).firstMatch(t);
    if (m != null) {
      final v = m.group(0)!;
      if (gemini) {
        if (v.startsWith('sk-or-')) return null;
        return v;
      }
      if (v.startsWith('sk-or-')) return v;
      return null;
    }
    if (!gemini && t.length >= 20 && !RegExp(r'\s').hasMatch(t)) {
      return t;
    }
    return null;
  }

  Future<QuizAiResolvedCredentials> _readStored() async {
    final values = await _vault.readAll();
    return QuizAiResolvedCredentials(
      geminiApiKey: values[_kGeminiKey] ?? '',
      geminiProxyUrl: values[_kGeminiProxy] ?? '',
      geminiModel: values[_kGeminiModel] ?? '',
      openRouterApiKey: values[_kOpenRouterKey] ?? '',
      openRouterProxyUrl: values[_kOpenRouterProxy] ?? '',
      openRouterModel: values[_kOpenRouterModel] ?? '',
    );
  }

  Future<void> _persistNonEmpty(QuizAiResolvedCredentials c) async {
    Future<void> write(String key, String value) async {
      final v = value.trim();
      if (v.isEmpty) return;
      await _vault.write(key: key, value: v);
    }

    await write(_kGeminiKey, c.geminiApiKey);
    await write(_kGeminiProxy, c.geminiProxyUrl);
    await write(_kGeminiModel, c.geminiModel);
    await write(_kOpenRouterKey, c.openRouterApiKey);
    await write(_kOpenRouterProxy, c.openRouterProxyUrl);
    await write(_kOpenRouterModel, c.openRouterModel);
  }

  static bool _hasPersistableCompileSecrets(QuizAiResolvedCredentials c) {
    return c.geminiApiKey.trim().isNotEmpty ||
        c.geminiProxyUrl.trim().isNotEmpty ||
        c.openRouterApiKey.trim().isNotEmpty ||
        c.openRouterProxyUrl.trim().isNotEmpty;
  }

  static String _prefer(String primary, String fallback) {
    final p = primary.trim();
    if (p.isNotEmpty) return p;
    return fallback.trim();
  }

  static QuizAiResolvedCredentials _normalize(QuizAiResolvedCredentials c) {
    return QuizAiResolvedCredentials(
      geminiApiKey: c.geminiApiKey.trim(),
      geminiProxyUrl: c.geminiProxyUrl.trim(),
      geminiModel: c.geminiModel.trim(),
      openRouterApiKey: c.openRouterApiKey.trim(),
      openRouterProxyUrl: c.openRouterProxyUrl.trim(),
      openRouterModel: c.openRouterModel.trim(),
    );
  }

  static bool get _isFlutterTest =>
      Platform.environment['FLUTTER_TEST'] == 'true';
}
