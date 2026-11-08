import 'package:firebase_core/firebase_core.dart';

/// Configuration Gemini partagée par tous les modules :
/// - Ressources : résumé et flashcards (`AiResourceService`) ;
/// - Groupes : rédaction / amélioration des descriptions
///   (`GeminiDescriptionService`).
///
/// La clé n'est JAMAIS stockée dans le code ni dans les assets (un asset est
/// embarqué en clair dans l'APK). Elle provient, par ordre de priorité :
/// 1. de la saisie dans l'application (dialogue « Clé API Gemini »), gardée
///    en mémoire pour la session uniquement ;
/// 2. de `--dart-define=GEMINI_API_KEY=...` ou
///    `--dart-define-from-file=dart_defines.json` (fichier ignoré par git).
class GeminiConfig {
  GeminiConfig._();

  /// Clé vide volontairement : elle vient de `dart_defines.json`
  /// (`flutter run --dart-define-from-file=dart_defines.json`), jamais du code.
  /// Clé intégrée à la demande du propriétaire du projet (utilisation de
  /// l'IA sans saisie). Ne pas publier ce fichier avec la clé sur un dépôt
  /// public : remettre '' avant de partager le code.
  static const String inlineApiKey = '';

  /// Saisie à l'exécution depuis le dialogue de l'application (non persistée).
  static String sessionApiKey = '';

  /// Essayés dans l'ordre. Mélanger les familles : la surcharge touche
  /// souvent une seule famille de modèles.
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
  static const String _envModel = String.fromEnvironment('GEMINI_MODEL');

  static String get apiKey {
    if (sessionApiKey.trim().isNotEmpty) return sessionApiKey.trim();
    if (_envKey.isNotEmpty) return _envKey;
    return inlineApiKey;
  }

  /// Modèle préféré (premier essayé) : `GEMINI_MODEL` s'il est défini,
  /// sinon le premier de [models].
  static String get model => _envModel.isNotEmpty ? _envModel : models.first;

  /// Aucune clé fournie : Gemini passe par Firebase AI Logic (projet
  /// StudyMate), sans clé dans l'application ni saisie.
  static bool get useFirebase => apiKey.isEmpty && Firebase.apps.isNotEmpty;

  static bool get isEnabled => apiKey.isNotEmpty || useFirebase;

  /// Message d'aide affiché quand aucune clé n'est disponible.
  static const String missingKeyHelp =
      'Clé API Gemini manquante. Saisissez-la dans l\'application ou lancez '
      'avec --dart-define-from-file=dart_defines.json.';
}
