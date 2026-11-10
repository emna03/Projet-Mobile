import '../models/ai_analysis.dart';
import '../models/quiz.dart';
import '../models/quiz_attempt.dart';

/// Fournisseur IA sélectionnable dans l’UI Quiz.
enum AiProviderKind { gemini, openRouter }

extension AiProviderKindLabel on AiProviderKind {
  String get label => switch (this) {
        AiProviderKind.gemini => 'Gemini',
        AiProviderKind.openRouter => 'OpenRouter',
      };

  String get shortId => switch (this) {
        AiProviderKind.gemini => 'gemini',
        AiProviderKind.openRouter => 'openrouter',
      };
}

/// Interface commune — Gemini et OpenRouter l’implémentent.
abstract class QuizAiProvider {
  String get displayName;
  AiProviderKind get kind;
  bool get isConfigured;

  Future<Quiz> generateQuiz({
    required String topic,
    required QuizDifficulty difficulty,
    required int questionCount,
  });

  Future<AiAnalysis> analyzeAttempt({
    required Quiz quiz,
    required QuizAttempt attempt,
  });

  /// Complétion texte brute (proxy ou API directe) — réutilisée par Knowledge Graph.
  Future<String> completeText(String prompt);

  void dispose();
}

/// Erreur métier partagée (tous fournisseurs).
class QuizAiException implements Exception {
  QuizAiException(this.message, {this.code, this.provider});

  final String message;
  final String? code;
  final String? provider;

  @override
  String toString() => message;
}
