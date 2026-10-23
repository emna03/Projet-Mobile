import 'package:flutter/material.dart';

import '../data/quiz_mock_data.dart';
import '../data/quiz_repository.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import '../models/quiz_result.dart';

class QuizViewModel extends ChangeNotifier {
  QuizViewModel({QuizRepository? repository})
      : _repository = repository ?? QuizRepository.seeded();

  final QuizRepository _repository;

  String searchQuery = '';
  String subjectFilter = 'Toutes';
  QuizDifficulty? difficultyFilter;

  Quiz? selectedQuiz;
  Quiz? sessionQuiz;
  int questionIndex = 0;
  int? selectedAnswer;
  bool answerValidated = false;
  final List<int?> sessionAnswers = [];

  bool isGenerating = false;
  Quiz? generatedQuiz;
  PedagogicalResource selectedResource = mockResources.first;
  QuizDifficulty aiDifficulty = QuizDifficulty.moyen;
  int aiQuestionCount = 8;

  String? errorMessage;

  List<Quiz> get quizzes => _repository.getAll();

  List<QuizResult> get history => _repository.getHistory();

  List<String> get subjects => _repository.subjects;

  Quiz? quizById(String id) => _repository.getById(id);

  List<Quiz> get filteredQuizzes {
    final query = searchQuery.trim().toLowerCase();
    return quizzes.where((quiz) {
      final matchesQuery = query.isEmpty ||
          quiz.title.toLowerCase().contains(query) ||
          quiz.subject.toLowerCase().contains(query);
      final matchesSubject = subjectFilter == 'Toutes' || quiz.subject == subjectFilter;
      final matchesDifficulty = difficultyFilter == null || quiz.difficulty == difficultyFilter;
      return matchesQuery && matchesSubject && matchesDifficulty;
    }).toList();
  }

  Question? get currentQuestion {
    final quiz = sessionQuiz;
    if (quiz == null || questionIndex >= quiz.questions.length) return null;
    return quiz.questions[questionIndex];
  }

  double get playProgress {
    final quiz = sessionQuiz;
    if (quiz == null || quiz.questions.isEmpty) return 0;
    return (questionIndex + 1) / quiz.questions.length;
  }

  int get estimatedAiMinutes => (aiQuestionCount * 1.2).round().clamp(5, 40);

  void setSearch(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void setSubject(String value) {
    subjectFilter = value;
    notifyListeners();
  }

  void setDifficulty(QuizDifficulty? value) {
    difficultyFilter = difficultyFilter == value ? null : value;
    notifyListeners();
  }

  void selectQuiz(Quiz quiz) {
    selectedQuiz = quiz;
    notifyListeners();
  }

  String? validateQuizDraft({
    required String title,
    required String subject,
    required int estimatedMinutes,
    required List<Question> questions,
  }) {
    if (title.trim().isEmpty) return 'Le titre du quiz est obligatoire.';
    if (subject.trim().isEmpty) return 'La matière est obligatoire.';
    if (estimatedMinutes < 1) return 'La durée doit être d’au moins 1 minute.';
    if (questions.isEmpty) return 'Ajoutez au moins une question.';
    for (var i = 0; i < questions.length; i++) {
      final question = questions[i];
      if (question.text.trim().isEmpty) {
        return 'L’énoncé de la question ${i + 1} est obligatoire.';
      }
      if (question.options.length < 2) {
        return 'La question ${i + 1} doit avoir au moins deux propositions.';
      }
      if (question.options.any((option) => option.trim().isEmpty)) {
        return 'Toutes les propositions de la question ${i + 1} doivent être renseignées.';
      }
      if (question.correctIndex < 0 || question.correctIndex >= question.options.length) {
        return 'Cochez la bonne réponse de la question ${i + 1}.';
      }
    }
    return null;
  }

  Quiz? createQuiz(Quiz quiz) {
    final error = validateQuizDraft(
      title: quiz.title,
      subject: quiz.subject,
      estimatedMinutes: quiz.estimatedMinutes,
      questions: quiz.questions,
    );
    if (error != null) {
      errorMessage = error;
      notifyListeners();
      return null;
    }
    errorMessage = null;
    final created = _repository.create(quiz.copyWith(id: ''));
    selectedQuiz = created;
    notifyListeners();
    return created;
  }

  Quiz? updateQuiz(Quiz quiz) {
    final error = validateQuizDraft(
      title: quiz.title,
      subject: quiz.subject,
      estimatedMinutes: quiz.estimatedMinutes,
      questions: quiz.questions,
    );
    if (error != null) {
      errorMessage = error;
      notifyListeners();
      return null;
    }
    errorMessage = null;
    final updated = _repository.update(quiz);
    selectedQuiz = updated;
    if (sessionQuiz?.id == updated.id) {
      sessionQuiz = updated;
    }
    notifyListeners();
    return updated;
  }

  bool deleteQuiz(String id) {
    final deleted = _repository.delete(id);
    if (selectedQuiz?.id == id) selectedQuiz = null;
    if (sessionQuiz?.id == id) sessionQuiz = null;
    if (generatedQuiz?.id == id) generatedQuiz = null;
    if (subjectFilter != 'Toutes' && !subjects.contains(subjectFilter)) {
      subjectFilter = 'Toutes';
    }
    notifyListeners();
    return deleted;
  }

  void startQuiz(Quiz quiz) {
    sessionQuiz = quiz;
    questionIndex = 0;
    selectedAnswer = null;
    answerValidated = false;
    sessionAnswers
      ..clear()
      ..addAll(List<int?>.filled(quiz.questions.length, null));
    notifyListeners();
  }

  void selectAnswer(int index) {
    if (answerValidated) return;
    selectedAnswer = index;
    notifyListeners();
  }

  void validateAnswer() {
    if (selectedAnswer == null || answerValidated) return;
    answerValidated = true;
    sessionAnswers[questionIndex] = selectedAnswer;
    notifyListeners();
  }

  bool goToNextQuestion() {
    final quiz = sessionQuiz;
    if (quiz == null || !answerValidated) return false;
    if (questionIndex + 1 >= quiz.questions.length) {
      return true;
    }
    questionIndex++;
    selectedAnswer = null;
    answerValidated = false;
    notifyListeners();
    return false;
  }

  QuizResult buildSessionResult() {
    final quiz = sessionQuiz!;
    var correct = 0;
    for (var i = 0; i < quiz.questions.length; i++) {
      if (sessionAnswers[i] == quiz.questions[i].correctIndex) {
        correct++;
      }
    }
    return QuizResult(
      quizId: quiz.id,
      quizTitle: quiz.title,
      subject: quiz.subject,
      difficulty: quiz.difficulty,
      dateLabel: _todayLabel(DateTime.now()),
      correctCount: correct,
      totalCount: quiz.questions.length,
    );
  }

  void completeSession() {
    if (sessionQuiz == null) return;
    _repository.addResult(buildSessionResult());
    notifyListeners();
  }

  void retryCurrentQuiz() {
    final quiz = sessionQuiz;
    if (quiz != null) {
      startQuiz(quiz);
    }
  }

  void selectResource(PedagogicalResource resource) {
    selectedResource = resource;
    notifyListeners();
  }

  void setAiDifficulty(QuizDifficulty difficulty) {
    aiDifficulty = difficulty;
    notifyListeners();
  }

  void setAiQuestionCount(double value) {
    aiQuestionCount = value.round().clamp(5, 20);
    notifyListeners();
  }

  Future<void> generateAiQuiz() async {
    isGenerating = true;
    generatedQuiz = null;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    generatedQuiz = aiQuizFor(selectedResource, aiDifficulty, aiQuestionCount);
    isGenerating = false;
    notifyListeners();
  }

  Quiz? saveGeneratedQuiz() {
    final quiz = generatedQuiz;
    if (quiz == null) return null;
    final created = _repository.create(quiz.copyWith(id: ''));
    generatedQuiz = created;
    selectedQuiz = created;
    notifyListeners();
    return created;
  }

  static String _todayLabel(DateTime date) {
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class QuizScope extends InheritedNotifier<QuizViewModel> {
  const QuizScope({
    super.key,
    required QuizViewModel notifier,
    required super.child,
  }) : super(notifier: notifier);

  static QuizViewModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<QuizScope>();
    assert(scope != null, 'QuizScope introuvable dans l\'arbre de widgets.');
    return scope!.notifier!;
  }
}
