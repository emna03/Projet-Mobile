import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/quiz_attempt_repository.dart';
import '../data/quiz_mock_data.dart';
import '../data/quiz_repository.dart';
import '../models/ai_analysis.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import '../models/quiz_attempt.dart';
import '../models/quiz_result.dart';
import '../knowledge_graph/services/knowledge_graph_engine.dart';
import '../services/difficulty_adapter.dart';
import '../services/gemini_exceptions.dart';
import '../services/gemini_service.dart';
import '../services/open_trivia_service.dart';
import '../services/openrouter_service.dart';
import '../services/quiz_ai_credential_store.dart';
import '../services/quiz_ai_provider.dart';
import '../services/quiz_user_context.dart';

class QuizViewModel extends ChangeNotifier {
  QuizViewModel({
    QuizRepository? repository,
    QuizAttemptRepository? attemptRepository,
    GeminiService? geminiService,
    OpenRouterService? openRouterService,
    OpenTriviaService? openTriviaService,
    QuizUserContext? userContext,
    Future<String?> Function()? aiAuthTokenProvider,
    DifficultyAdapter difficultyAdapter = const DifficultyAdapter(),
    KnowledgeGraphEngine? knowledgeGraphEngine,
    QuizAiCredentialStore? aiCredentialStore,
  })  : _repository = repository ?? QuizRepository.seeded(),
        _attemptRepository = attemptRepository ?? QuizAttemptRepository(),
        _gemini = geminiService ??
            GeminiService(
              config: GeminiConfig(authTokenProvider: aiAuthTokenProvider),
            ),
        _openRouter = openRouterService ??
            OpenRouterService(
              config: OpenRouterConfig(authTokenProvider: aiAuthTokenProvider),
            ),
        _openTrivia = openTriviaService ?? OpenTriviaService(),
        _userContext = userContext ?? QuizUserContext(),
        _difficultyAdapter = difficultyAdapter,
        _knowledgeGraph = knowledgeGraphEngine ?? KnowledgeGraphEngine(),
        _aiCredentialStore = aiCredentialStore ?? QuizAiCredentialStore(),
        _aiServicesInjected =
            geminiService != null || openRouterService != null;

  final QuizRepository _repository;
  final QuizAttemptRepository _attemptRepository;
  final GeminiService _gemini;
  final OpenRouterService _openRouter;
  final OpenTriviaService _openTrivia;
  final QuizUserContext _userContext;
  final DifficultyAdapter _difficultyAdapter;
  final KnowledgeGraphEngine _knowledgeGraph;
  final QuizAiCredentialStore _aiCredentialStore;
  final bool _aiServicesInjected;

  String searchQuery = '';
  String subjectFilter = 'Toutes';
  QuizDifficulty? difficultyFilter;

  Quiz? selectedQuiz;
  Quiz? sessionQuiz;
  int questionIndex = 0;
  int? selectedAnswer;
  bool answerValidated = false;
  final List<int?> sessionAnswers = [];
  String sessionSource = 'local';

  bool isGenerating = false;
  bool isFetchingOnline = false;
  bool isAnalyzing = false;
  bool isLoadingStore = false;
  Quiz? generatedQuiz;
  String aiTopic = '';
  QuizDifficulty aiDifficulty = QuizDifficulty.moyen;
  int aiQuestionCount = 5;
  AiProviderKind selectedAiProvider = AiProviderKind.gemini;

  /// Difficulté suggérée après une tentative (locale ± IA).
  QuizDifficulty? suggestedDifficulty;
  String? difficultySuggestionReason;

  OpenTriviaCategory onlineCategory = OpenTriviaService.categories.first;
  QuizDifficulty onlineDifficulty = QuizDifficulty.moyen;
  int onlineQuestionCount = 5;
  Quiz? onlineQuiz;

  List<QuizAttempt> attempts = const [];
  QuizAttempt? lastAttempt;
  AiAnalysis? lastAnalysis;
  String? currentUserId;

  String? errorMessage;

  QuizAiProvider get _activeAi =>
      selectedAiProvider == AiProviderKind.openRouter ? _openRouter : _gemini;

  bool get geminiConfigured => _gemini.isConfigured;
  bool get openRouterConfigured => _openRouter.isConfigured;
  bool get activeAiConfigured => _activeAi.isConfigured;
  bool get anyAiConfigured => geminiConfigured || openRouterConfigured;

  /// Config runtime déjà résolue — pour synchroniser Knowledge Map (pas de copie des secrets).
  GeminiConfig get geminiRuntimeConfig => _gemini.config;
  OpenRouterConfig get openRouterRuntimeConfig => _openRouter.config;

  String get activeAiLabel => _activeAi.displayName;

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
      final matchesDifficulty =
          difficultyFilter == null || quiz.difficulty == difficultyFilter;
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

  Future<void> bootstrap() async {
    isLoadingStore = true;
    if (hasListeners) notifyListeners();
    try {
      await _repository.load();
    } catch (_) {
      // SQLite indisponible : le repository mémoire n’a rien à charger.
    }
    if (!_aiServicesInjected) {
      await _applyResolvedAiCredentials();
    }
    currentUserId = await _userContext.currentUserId();
    await refreshAttempts();
    applyDifficultyFromHistory();
    isLoadingStore = false;
    if (hasListeners) notifyListeners();
  }

  /// Charge dart-define + stockage sécurisé ; n’active jamais une clé vide.
  Future<void> _applyResolvedAiCredentials() async {
    try {
      final resolved = await _aiCredentialStore.resolveAndMaybePersist();
      final gemini = GeminiConfig(
        apiKey: resolved.geminiApiKey,
        proxyUrl: resolved.geminiProxyUrl,
        model: resolved.geminiModel.isEmpty ? null : resolved.geminiModel,
        authTokenProvider: _gemini.config.authTokenProvider,
      );
      final openRouter = OpenRouterConfig(
        apiKey: resolved.openRouterApiKey,
        proxyUrl: resolved.openRouterProxyUrl,
        model:
            resolved.openRouterModel.isEmpty ? null : resolved.openRouterModel,
        authTokenProvider: _openRouter.config.authTokenProvider,
      );
      _gemini.reconfigure(gemini);
      _openRouter.reconfigure(openRouter);
      _knowledgeGraph.applyAiConfigs(
        gemini: gemini,
        openRouter: openRouter,
        preferred: selectedAiProvider,
      );
      if (kDebugMode) {
        // Booléens uniquement — jamais de secret.
        debugPrint(
          'QuizAI status geminiConfigured=$geminiConfigured '
          'openRouterConfigured=$openRouterConfigured',
        );
      }
    } catch (_) {
      // Conserve la config compile-time déjà injectée dans les services.
    }
  }

  /// Importe la clé du fournisseur actif depuis le presse-papiers.
  /// N’écrase pas une clé déjà stockée ; refuse une valeur vide / invalide.
  Future<bool> importActiveProviderKeyFromClipboard() async {
    if (_aiServicesInjected) return activeAiConfigured;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text ?? '';
    final ok = await _aiCredentialStore.saveKeyIfAbsent(
      gemini: selectedAiProvider == AiProviderKind.gemini,
      raw: raw,
    );
    if (!ok) {
      errorMessage =
          'Presse-papiers vide ou configuration invalide.';
      notifyListeners();
      return false;
    }
    await _applyResolvedAiCredentials();
    errorMessage = activeAiConfigured
        ? null
        : 'La génération intelligente n’a pas pu être activée.';
    notifyListeners();
    return activeAiConfigured;
  }

  Future<void> refreshAttempts() async {
    try {
      final uid = currentUserId ?? await _userContext.currentUserId();
      currentUserId = uid;
      attempts = await _attemptRepository.listForUser(uid);
    } catch (_) {
      attempts = const [];
    }
    if (hasListeners) {
      notifyListeners();
    }
  }

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

  void setAiProvider(AiProviderKind kind) {
    selectedAiProvider = kind;
    errorMessage = null;
    notifyListeners();
  }

  void setAiTopic(String value) {
    aiTopic = value;
    notifyListeners();
  }

  void setAiDifficulty(QuizDifficulty difficulty) {
    aiDifficulty = difficulty;
    notifyListeners();
  }

  void setAiQuestionCount(int value) {
    aiQuestionCount = value.clamp(5, 15);
    if (aiQuestionCount != 5 && aiQuestionCount != 10 && aiQuestionCount != 15) {
      if (aiQuestionCount < 8) {
        aiQuestionCount = 5;
      } else if (aiQuestionCount < 13) {
        aiQuestionCount = 10;
      } else {
        aiQuestionCount = 15;
      }
    }
    notifyListeners();
  }

  void setOnlineCategory(OpenTriviaCategory category) {
    onlineCategory = category;
    notifyListeners();
  }

  void setOnlineDifficulty(QuizDifficulty difficulty) {
    onlineDifficulty = difficulty;
    notifyListeners();
  }

  void setOnlineQuestionCount(int value) {
    onlineQuestionCount = value.clamp(5, 15);
    if (onlineQuestionCount != 5 &&
        onlineQuestionCount != 10 &&
        onlineQuestionCount != 15) {
      onlineQuestionCount = onlineQuestionCount < 8
          ? 5
          : onlineQuestionCount < 13
              ? 10
              : 15;
    }
    notifyListeners();
  }

  /// Applique la difficulté adaptée à la génération IA et Open Trivia.
  void applySuggestedDifficultyToForms() {
    final d = suggestedDifficulty;
    if (d == null) return;
    aiDifficulty = d;
    onlineDifficulty = d;
    notifyListeners();
  }

  void applyDifficultyFromHistory({String? subject}) {
    final adapted = _difficultyAdapter.fromHistory(
      attempts: attempts,
      subject: subject,
      fallback: aiDifficulty,
    );
    suggestedDifficulty = adapted;
    difficultySuggestionReason =
        'Basé sur tes ${attempts.isEmpty ? 0 : attempts.take(3).length} dernière(s) tentative(s).';
    applySuggestedDifficultyToForms();
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
      if (question.correctIndex < 0 ||
          question.correctIndex >= question.options.length) {
        return 'Cochez la bonne réponse de la question ${i + 1}.';
      }
    }
    return null;
  }

  Future<Quiz?> createQuiz(Quiz quiz) async {
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
    final created = await _repository.create(quiz.copyWith(id: ''));
    selectedQuiz = created;
    notifyListeners();
    return created;
  }

  Future<Quiz?> updateQuiz(Quiz quiz) async {
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
    final updated = await _repository.update(quiz);
    selectedQuiz = updated;
    if (sessionQuiz?.id == updated.id) {
      sessionQuiz = updated;
    }
    notifyListeners();
    return updated;
  }

  Future<bool> deleteQuiz(String id) async {
    final deleted = await _repository.delete(id);
    if (selectedQuiz?.id == id) selectedQuiz = null;
    if (sessionQuiz?.id == id) sessionQuiz = null;
    if (generatedQuiz?.id == id) generatedQuiz = null;
    if (subjectFilter != 'Toutes' && !subjects.contains(subjectFilter)) {
      subjectFilter = 'Toutes';
    }
    notifyListeners();
    return deleted;
  }

  void startQuiz(Quiz quiz, {String source = 'local'}) {
    sessionQuiz = quiz;
    sessionSource = source;
    questionIndex = 0;
    selectedAnswer = null;
    answerValidated = false;
    lastAttempt = null;
    lastAnalysis = null;
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

  Future<QuizAttempt?> completeSession() async {
    final quiz = sessionQuiz;
    if (quiz == null) return null;
    final result = buildSessionResult();
    try {
      await _repository.addResult(result);
    } catch (_) {}

    final uid = currentUserId ?? await _userContext.currentUserId();
    currentUserId = uid;
    final attempt = QuizAttempt(
      id: 'att-${DateTime.now().millisecondsSinceEpoch}',
      userId: uid,
      quizId: quiz.id.isEmpty ? 'unsaved-${quiz.title.hashCode}' : quiz.id,
      quizTitle: quiz.title,
      subject: quiz.subject,
      difficulty: quiz.difficulty,
      correctCount: result.correctCount,
      totalCount: result.totalCount,
      selectedAnswers: List<int?>.from(sessionAnswers),
      completedAt: DateTime.now(),
      source: sessionSource,
    );
    try {
      await _attemptRepository.save(attempt);
    } catch (_) {}
    lastAttempt = attempt;
    await refreshAttempts();

    // Adaptation locale immédiate (sans attendre l’IA).
    suggestedDifficulty = _difficultyAdapter.fromScore(
      current: quiz.difficulty,
      scorePercent: attempt.scorePercent,
    );
    difficultySuggestionReason =
        'Score ${attempt.scorePercent}% → difficulté ${suggestedDifficulty!.label}.';
    applySuggestedDifficultyToForms();

    // Knowledge Graph : mise à jour évolutive (heuristique locale ; IA si dispo).
    // Ignoré sous FLUTTER_TEST (repos mémoire / pas de sqflite prêt).
    final inFlutterTest = Platform.environment['FLUTTER_TEST'] == 'true';
    if (!inFlutterTest) {
      try {
        await _knowledgeGraph.afterAttempt(
          quiz: quiz,
          attempt: attempt,
          allUserAttempts: attempts,
          allQuizzes: quizzes,
          allowNetwork: activeAiConfigured,
        );
      } catch (_) {
        // Ne bloque jamais la fin de session quiz.
      }
    }

    return attempt;
  }

  int? progressForCurrentQuiz() {
    final attempt = lastAttempt;
    if (attempt == null) return null;
    final related = attempts.where((a) => a.quizId == attempt.quizId).toList();
    return _attemptRepository.progressDeltaPercent(attemptsForQuiz: related);
  }

  void retryCurrentQuiz() {
    final quiz = sessionQuiz;
    if (quiz == null) return;
    final adapted = suggestedDifficulty ?? quiz.difficulty;
    // Relance au même contenu ; la difficulté adaptée sert aux prochains quiz générés.
    startQuiz(quiz.copyWith(difficulty: adapted), source: sessionSource);
  }

  Future<void> generateAiQuiz() async {
    errorMessage = null;
    isGenerating = true;
    generatedQuiz = null;
    notifyListeners();
    try {
      final topic = aiTopic.trim();
      if (topic.isEmpty) {
        throw QuizAiException(
          'Saisissez un sujet ou le contenu du cours.',
          code: 'validation',
          provider: activeAiLabel,
        );
      }
      generatedQuiz = await _activeAi.generateQuiz(
        topic: topic,
        difficulty: aiDifficulty,
        questionCount: aiQuestionCount,
      );
    } on GeminiException catch (e) {
      errorMessage = e.message;
      generatedQuiz = null;
    } on QuizAiException catch (e) {
      errorMessage = e.message;
      generatedQuiz = null;
    } catch (e) {
      errorMessage = 'Erreur inattendue lors de la génération : $e';
      generatedQuiz = null;
    } finally {
      isGenerating = false;
      notifyListeners();
    }
  }

  void updateGeneratedQuiz(Quiz quiz) {
    generatedQuiz = quiz;
    notifyListeners();
  }

  Future<Quiz?> saveGeneratedQuiz() async {
    final quiz = generatedQuiz;
    if (quiz == null) return null;
    final created =
        await _repository.create(quiz.copyWith(id: '', generatedByAi: true));
    generatedQuiz = created;
    selectedQuiz = created;
    notifyListeners();
    return created;
  }

  Future<void> fetchOnlineQuiz() async {
    errorMessage = null;
    isFetchingOnline = true;
    onlineQuiz = null;
    notifyListeners();
    try {
      onlineQuiz = await _openTrivia.fetchQuiz(
        amount: onlineQuestionCount,
        difficulty: onlineDifficulty,
        categoryId: onlineCategory.id,
      );
    } on OpenTriviaException catch (e) {
      errorMessage = e.message;
      onlineQuiz = null;
    } catch (e) {
      errorMessage = 'Impossible de charger les quiz prêts à jouer. Réessayez.';
      onlineQuiz = null;
    } finally {
      isFetchingOnline = false;
      notifyListeners();
    }
  }

  Future<Quiz?> saveOnlineQuiz() async {
    final quiz = onlineQuiz;
    if (quiz == null) return null;
    final created = await _repository.create(quiz.copyWith(id: ''));
    onlineQuiz = created;
    selectedQuiz = created;
    notifyListeners();
    return created;
  }

  Future<AiAnalysis?> analyzeLastAttempt() async {
    final quiz = sessionQuiz;
    final attempt = lastAttempt;
    if (quiz == null || attempt == null) {
      errorMessage = 'Aucune tentative à analyser.';
      notifyListeners();
      return null;
    }

    errorMessage = null;
    isAnalyzing = true;
    lastAnalysis = null;
    notifyListeners();
    try {
      final analysis =
          await _activeAi.analyzeAttempt(quiz: quiz, attempt: attempt);
      lastAnalysis = analysis;
      suggestedDifficulty = _difficultyAdapter.resolve(
        current: quiz.difficulty,
        scorePercent: attempt.scorePercent,
        analysis: analysis,
      );
      difficultySuggestionReason =
          'IA ($activeAiLabel) + score ${attempt.scorePercent}% → ${suggestedDifficulty!.label}.';
      applySuggestedDifficultyToForms();

      await _attemptRepository.updateAnalysis(
        attemptId: attempt.id,
        analysisJson: jsonEncode(analysis.toJson()),
      );
      await refreshAttempts();
      return analysis;
    } on GeminiException catch (e) {
      errorMessage = e.message;
      lastAnalysis = null;
      return null;
    } on QuizAiException catch (e) {
      errorMessage = e.message;
      lastAnalysis = null;
      return null;
    } catch (e) {
      errorMessage = 'Erreur analyse IA : $e';
      lastAnalysis = null;
      return null;
    } finally {
      isAnalyzing = false;
      notifyListeners();
    }
  }

  /// Conservé pour compatibilité avec d’anciens appels UI (ressources mock).
  @Deprecated('Utiliser setAiTopic + generateAiQuiz')
  void selectResource(PedagogicalResource resource) {
    aiTopic = resource.title;
    notifyListeners();
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

  @override
  void dispose() {
    _gemini.dispose();
    _openRouter.dispose();
    _openTrivia.dispose();
    _knowledgeGraph.dispose();
    super.dispose();
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
