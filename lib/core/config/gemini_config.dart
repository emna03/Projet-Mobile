class GeminiConfig {
  /// Clé vide volontairement : elle vient de `dart_defines.json`
  /// (`flutter run --dart-define-from-file=dart_defines.json`), jamais du code.
  static const String inlineApiKey = '';

  /// Set at runtime from the in-app dialog (not committed).
  static String sessionApiKey = '';

  /// Tried in order. Mix model families: overload often hits one family.
  static const List<String> models = [
    'gemini-3.5-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  static const String endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const String _envKey = String.fromEnvironment('GEMINI_API_KEY');

  static String get apiKey {
    if (sessionApiKey.trim().isNotEmpty) return sessionApiKey.trim();
    if (_envKey.isNotEmpty) return _envKey;
    return inlineApiKey;
  }

  static bool get isEnabled => apiKey.isNotEmpty;
}