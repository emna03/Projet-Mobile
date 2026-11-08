import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/ai_firebase_options.dart';

/// Erreur Gemini (via Firebase) avec un message en français.
class FirebaseGeminiException implements Exception {
  FirebaseGeminiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Accès à Gemini via Firebase AI Logic : AUCUNE clé API dans l'application.
///
/// Les appels passent par le projet Firebase de StudyMate (déjà configuré
/// dans `firebase_options.dart`). Partagé par les trois usages IA :
/// descriptions de groupes, résumés et flashcards des ressources.
///
/// Prérequis (une seule fois) : Console Firebase → AI Logic → « Get started »
/// → « Gemini Developer API ».
class FirebaseGemini {
  FirebaseGemini._();

  static const _attemptTimeout = Duration(seconds: 60);

  static Future<FirebaseApp>? _app;

  /// Projet Firebase utilisé pour Gemini : le projet IA dédié s'il est
  /// configuré ([AiFirebaseOptions]), sinon le projet principal.
  static Future<FirebaseApp> _aiApp() => _app ??= () async {
        final options = AiFirebaseOptions.currentPlatform;
        if (options == null) return Firebase.app();
        for (final app in Firebase.apps) {
          if (app.name == AiFirebaseOptions.appName) return app;
        }
        return Firebase.initializeApp(name: AiFirebaseOptions.appName, options: options);
      }();

  /// Génère du texte en essayant [models] dans l'ordre. Les erreurs
  /// passagères (réseau, surcharge, quota) sont réessayées automatiquement.
  static Future<String> generate({
    required List<String> models,
    required String prompt,
    String? systemInstruction,
    double? temperature,
    int? maxOutputTokens,
    bool minimalThinking = false,
    Uint8List? inlineBytes,
    String? inlineMime,
    String? responseMimeType,
    Schema? responseSchema,
    Duration totalBudget = const Duration(seconds: 120),
  }) async {
    final app = await _aiApp();
    final stopwatch = Stopwatch()..start();
    FirebaseGeminiException? lastError;

    for (final model in models.toSet()) {
      for (var attempt = 0; attempt < 2; attempt++) {
        if (stopwatch.elapsed > totalBudget) break;
        try {
          final generative = FirebaseAI.googleAI(app: app).generativeModel(
            model: model,
            systemInstruction:
                systemInstruction == null ? null : Content.system(systemInstruction),
            generationConfig: GenerationConfig(
              temperature: temperature,
              maxOutputTokens: maxOutputTokens,
              responseMimeType: responseMimeType,
              responseSchema: responseSchema,
              // `thinkingLevel` n'existe que pour les modèles Gemini 3.
              thinkingConfig: minimalThinking && model.startsWith('gemini-3')
                  ? ThinkingConfig.withThinkingLevel(ThinkingLevel.minimal)
                  : null,
            ),
          );
          final content = Content.multi([
            if (inlineBytes != null && inlineMime != null)
              InlineDataPart(inlineMime, inlineBytes),
            TextPart(prompt),
          ]);
          final response =
              await generative.generateContent([content]).timeout(_attemptTimeout);
          final text = (response.text ?? '').trim();
          if (text.isNotEmpty) return text;
          lastError = FirebaseGeminiException(
              'Gemini n\'a renvoyé aucune réponse. Réessayez.');
          break; // réponse vide : modèle suivant
        } on ServiceApiNotEnabled {
          throw FirebaseGeminiException(
            'Gemini n\'est pas encore activé pour ce projet. Console Firebase → '
            'AI Logic → « Get started » (Gemini Developer API), puis réessayez '
            'dans quelques minutes.',
          );
        } on InvalidApiKey {
          throw FirebaseGeminiException(
              'Configuration Firebase invalide pour Gemini (clé du projet).');
        } on UnsupportedUserLocation {
          throw FirebaseGeminiException(
              'Gemini n\'est pas disponible dans votre région.');
        } on QuotaExceeded catch (e) {
          debugPrint('FirebaseGemini quota ($model): ${e.message}');
          lastError = FirebaseGeminiException(
              'Quota Gemini atteint. Patientez quelques instants.');
          break; // autre modèle = autre quota
        } on TimeoutException {
          lastError = FirebaseGeminiException(
              'Le service IA met trop de temps à répondre. Réessayez.');
          break;
        } catch (e) {
          // Surcharge (503), modèle introuvable (404), réseau pas prêt…
          debugPrint('FirebaseGemini ($model, essai ${attempt + 1}): $e');
          final text = e.toString().toLowerCase();
          lastError = FirebaseGeminiException(
            text.contains('socket') || text.contains('network') || text.contains('connection')
                ? 'Pas de connexion Internet. Vérifiez votre réseau.'
                : 'Le service Gemini est momentanément indisponible. Réessayez.',
          );
          if (text.contains('not found') || text.contains('404')) break;
          await Future<void>.delayed(Duration(milliseconds: 700 * (attempt + 1)));
        }
      }
    }
    throw lastError ??
        FirebaseGeminiException('Le service Gemini est momentanément indisponible.');
  }
}
