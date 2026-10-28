import 'dart:convert';

import 'package:flutter/services.dart';

/// Resolves the Gemini API settings once at startup.
///
/// Priority:
/// 1. `--dart-define=GEMINI_API_KEY=...` (or `--dart-define-from-file`)
/// 2. The bundled `assets/config/gemini_config.json` file (gitignored), so the
///    app also works when launched from an IDE "Run" button without flags.
class GeminiConfig {
  GeminiConfig._();

  static const assetPath = 'assets/config/gemini_config.json';
  static const _defaultModel = 'gemini-3.5-flash';

  static String _apiKey = const String.fromEnvironment('GEMINI_API_KEY');
  static String _model = const String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: _defaultModel,
  );

  static String get apiKey => _apiKey;
  static String get model => _model;

  /// Reads the bundled config file when no key was passed on the command line.
  static Future<void> load() async {
    if (_apiKey.isNotEmpty) return;
    try {
      final raw = await rootBundle.loadString(assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _apiKey = (json['GEMINI_API_KEY'] as String? ?? '').trim();
      final model = (json['GEMINI_MODEL'] as String? ?? '').trim();
      if (model.isNotEmpty) _model = model;
    } catch (_) {
      // File absent or malformed: the assistant will report a missing key.
    }
  }
}
