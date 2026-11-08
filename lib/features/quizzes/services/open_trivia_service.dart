import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/question.dart';
import '../models/quiz.dart';

class OpenTriviaException implements Exception {
  OpenTriviaException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

class OpenTriviaCategory {
  const OpenTriviaCategory({required this.id, required this.name});
  final int id;
  final String name;
}

/// API publique Open Trivia Database (pas une IA).
class OpenTriviaService {
  OpenTriviaService({
    http.Client? client,
    Duration timeout = const Duration(seconds: 25),
    Random? random,
  })  : _client = client ?? http.Client(),
        _timeout = timeout,
        _random = random ?? Random();

  final http.Client _client;
  final Duration _timeout;
  final Random _random;

  static const categories = <OpenTriviaCategory>[
    OpenTriviaCategory(id: 9, name: 'Culture générale'),
    OpenTriviaCategory(id: 17, name: 'Science & Nature'),
    OpenTriviaCategory(id: 18, name: 'Informatique'),
    OpenTriviaCategory(id: 19, name: 'Mathématiques'),
    OpenTriviaCategory(id: 23, name: 'Histoire'),
    OpenTriviaCategory(id: 22, name: 'Géographie'),
  ];

  Future<Quiz> fetchQuiz({
    required int amount,
    required QuizDifficulty difficulty,
    int? categoryId,
  }) async {
    final count = amount.clamp(5, 15);
    final params = <String, String>{
      'amount': '$count',
      'type': 'multiple',
      'difficulty': switch (difficulty) {
        QuizDifficulty.facile => 'easy',
        QuizDifficulty.moyen => 'medium',
        QuizDifficulty.difficile => 'hard',
      },
    };
    if (categoryId != null) {
      params['category'] = '$categoryId';
    }

    final uri = Uri.https('opentdb.com', '/api.php', params);

    late http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw OpenTriviaException('Délai dépassé Open Trivia DB.', code: 'timeout');
    } on SocketException catch (e) {
      throw OpenTriviaException('Réseau indisponible : ${e.message}', code: 'network');
    } on http.ClientException catch (e) {
      throw OpenTriviaException('Réseau : ${e.message}', code: 'network');
    }

    if (response.statusCode == 429) {
      throw OpenTriviaException('Limite de requêtes Open Trivia atteinte.', code: 'rate_limit');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenTriviaException('HTTP ${response.statusCode}', code: 'http');
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw OpenTriviaException('Réponse Open Trivia invalide.', code: 'invalid');
    }

    final responseCode = body['response_code'];
    if (responseCode != 0) {
      throw OpenTriviaException(
        'Aucune question disponible (code $responseCode).',
        code: 'empty',
      );
    }

    final results = body['results'];
    if (results is! List || results.isEmpty) {
      throw OpenTriviaException('Liste de questions vide.', code: 'empty');
    }

    final questions = <Question>[];
    for (var i = 0; i < results.length; i++) {
      final item = results[i];
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final questionText = _decodeHtml(map['question']?.toString() ?? '');
      final correct = _decodeHtml(map['correct_answer']?.toString() ?? '');
      final incorrect = (map['incorrect_answers'] as List<dynamic>? ?? const [])
          .map((e) => _decodeHtml(e.toString()))
          .toList();
      if (questionText.isEmpty || correct.isEmpty || incorrect.length != 3) {
        continue;
      }
      final options = [...incorrect, correct]..shuffle(_random);
      final correctIndex = options.indexOf(correct);
      questions.add(
        Question(
          id: 'otdb-$i-${DateTime.now().microsecondsSinceEpoch}',
          text: questionText,
          options: options,
          correctIndex: correctIndex < 0 ? 0 : correctIndex,
          explanation: 'Bonne réponse : $correct',
          difficulty: difficulty,
        ),
      );
    }

    if (questions.isEmpty) {
      throw OpenTriviaException('Impossible de convertir les questions.', code: 'convert');
    }

    final matched = categories.where((c) => c.id == categoryId).toList();
    final categoryName = matched.isEmpty ? 'Open Trivia' : matched.first.name;

    return Quiz(
      id: '',
      title: 'Quiz en ligne — $categoryName',
      description:
          'Quiz prêt à jouer — questions préparées par catégorie.',
      subject: categoryName,
      difficulty: difficulty,
      estimatedMinutes: (questions.length * 1.1).round().clamp(5, 40),
      questions: questions,
      generatedByAi: false,
    );
  }

  /// Décodage minimal des entités HTML renvoyées par OpenTDB.
  static String _decodeHtml(String input) {
    return input
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
          final code = int.tryParse(m.group(1)!);
          return code == null ? m.group(0)! : String.fromCharCode(code);
        })
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
          final code = int.tryParse(m.group(1)!, radix: 16);
          return code == null ? m.group(0)! : String.fromCharCode(code);
        });
  }

  void dispose() {
    _client.close();
  }
}
