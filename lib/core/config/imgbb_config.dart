/// Clé ImgBB (hébergement du justificatif enseignant et des photos de profil
/// partagées avec les autres membres).
///
/// Centralisée ici au lieu d'être recopiée dans les écrans. Elle peut être
/// surchargée par `--dart-define=IMGBB_API_KEY=...`. La valeur par défaut est
/// celle déjà présente dans le projet : une clé embarquée dans une application
/// mobile reste extractible ; voir le rapport d'intégration.
class ImgBBConfig {
  ImgBBConfig._();

  static const String _envKey = String.fromEnvironment('IMGBB_API_KEY');
  static const String _legacyKey = 'ffaedce924de3cc77dde73e869ed3cd4';

  static String get apiKey => _envKey.isNotEmpty ? _envKey : _legacyKey;
}
