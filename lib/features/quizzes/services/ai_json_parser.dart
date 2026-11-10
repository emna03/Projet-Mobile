import 'dart:convert';

import '../models/question.dart';
import '../models/quiz.dart';
import 'quiz_ai_provider.dart';

/// Parsing JSON partagé (Gemini / OpenRouter) — aucun résultat inventé.
class AiJsonParser {
  const AiJsonParser();

  Map<String, dynamic> extractJsonObject(String raw) {
    final trimmed = raw.trim();
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // try fenced / embedded
    }
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final decoded = jsonDecode(trimmed.substring(start, end + 1));
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (e) {
        throw QuizAiException(
          'Réponse IA JSON invalide : $e',
          code: 'invalid_json',
        );
      }
    }
    throw QuizAiException(
      'Réponse IA JSON invalide ou incomplète.',
      code: 'invalid_json',
    );
  }

  Quiz quizFromGeneratedJson(
    Map<String, dynamic> json, {
    required QuizDifficulty difficulty,
    required String topic,
    required String generatedByLabel,
  }) {
    final questionsRaw = json['questions'];
    if (questionsRaw is! List || questionsRaw.isEmpty) {
      throw QuizAiException(
        'Réponse IA JSON invalide : questions manquantes',
        code: 'invalid_json',
      );
    }

    final questions = <Question>[];
    for (var i = 0; i < questionsRaw.length; i++) {
      final item = questionsRaw[i];
      if (item is! Map) {
        throw QuizAiException(
          'Réponse IA JSON invalide : question $i invalide',
          code: 'invalid_json',
        );
      }
      final map = Map<String, dynamic>.from(item);
      final question = Question.fromJson(map, fallbackId: 'ai-$i');
      if (question.text.trim().isEmpty || question.options.length != 4) {
        throw QuizAiException(
          'Réponse IA JSON invalide : question $i incomplète',
          code: 'invalid_json',
        );
      }
      if (question.correctIndex < 0 || question.correctIndex > 3) {
        throw QuizAiException(
          'Réponse IA JSON invalide : bonne réponse invalide ($i)',
          code: 'invalid_json',
        );
      }
      if (question.explanation.trim().isEmpty) {
        throw QuizAiException(
          'Réponse IA JSON invalide : explication manquante ($i)',
          code: 'invalid_json',
        );
      }
      questions.add(question);
    }

    final minutes = json['estimatedMinutes'];
    final estimated = minutes is int
        ? minutes
        : int.tryParse(minutes?.toString() ?? '') ??
            (questions.length * 1.2).round();

    return Quiz(
      id: '',
      title: json['title']?.toString().trim().isNotEmpty == true
          ? json['title'].toString().trim()
          : 'Quiz IA — $topic',
      description: json['description']?.toString().trim().isNotEmpty == true
          ? json['description'].toString().trim()
          : 'Quiz généré par $generatedByLabel pour « $topic ».',
      subject: json['subject']?.toString().trim().isNotEmpty == true
          ? json['subject'].toString().trim()
          : topic,
      difficulty: difficulty,
      estimatedMinutes: estimated.clamp(5, 60),
      questions: questions,
      generatedByAi: true,
    );
  }

  String buildGeneratePrompt({
    required String topic,
    required QuizDifficulty difficulty,
    required int count,
  }) {
    return '''
Tu es un professeur. Génère un quiz éducatif en français.
Sujet / contenu du cours : $topic
Difficulté globale : ${difficulty.label}
Nombre de questions : $count

Réponds UNIQUEMENT avec un JSON valide de la forme :
{
  "title": "string",
  "description": "string",
  "subject": "string",
  "estimatedMinutes": number,
  "questions": [
    {
      "text": "string",
      "options": ["A","B","C","D"],
      "correctIndex": 0,
      "explanation": "string pédagogique",
      "difficulty": "facile|moyen|difficile"
    }
  ]
}
Règles strictes :
- exactement $count questions
- exactement 4 options par question
- une seule bonne réponse (correctIndex 0..3)
- explication pédagogique non vide
''';
  }

  String buildAnalyzePrompt({
    required Quiz quiz,
    required int correctCount,
    required int totalCount,
    required int scorePercent,
    required List<Map<String, dynamic>> wrong,
  }) {
    return '''
Tu es un tuteur pédagogique. Analyse les résultats RÉELS suivants (ne invente pas de score).
Quiz : ${quiz.title}
Matière : ${quiz.subject}
Score réel : $correctCount/$totalCount ($scorePercent%)
Erreurs :
${jsonEncode(wrong)}

Réponds UNIQUEMENT avec un JSON :
{
  "personalizedExplanation": "string",
  "topicsToReview": ["notion1","notion2"],
  "revisionTips": ["conseil1","conseil2","conseil3"],
  "nextDifficulty": "facile|moyen|difficile"
}
Base-toi uniquement sur ces erreurs et ce score.
''';
  }
}
