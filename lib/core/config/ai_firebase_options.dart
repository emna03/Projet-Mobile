import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Projet Firebase dédié à l'IA (Firebase AI Logic / Gemini).
///
/// L'authentification, les groupes et le chat restent sur le projet principal
/// (`firebase_options.dart`, studymate-23d1f). Seuls les appels Gemini passent
/// par ce second projet, auquel l'équipe a accès pour activer AI Logic.
///
/// Ces valeurs sont une configuration CLIENT Firebase (comme
/// `firebase_options.dart`) : ce ne sont pas des secrets. Elles proviennent de
/// l'application Android `com.example.studymate` enregistrée dans ce projet.
///
/// `null` = pas de projet IA dédié pour cette plateforme : le projet
/// principal est utilisé.
class AiFirebaseOptions {
  AiFirebaseOptions._();

  /// Nom de l'instance Firebase secondaire.
  static const appName = 'studymate-ai';

  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      _ => null,
    };
  }

  /// À compléter avec le google-services.json du projet IA.
  static const FirebaseOptions? android = null;
}
