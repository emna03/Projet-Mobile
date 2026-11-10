import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studymate/features/quizzes/data/memory_quiz_attempt_repository.dart';
import 'package:studymate/features/quizzes/data/quiz_repository.dart';
import 'package:studymate/features/quizzes/models/quiz.dart';
import 'package:studymate/features/quizzes/models/question.dart';
import 'package:studymate/features/quizzes/services/gemini_service.dart';
import 'package:studymate/features/quizzes/services/openrouter_service.dart';
import 'package:studymate/features/quizzes/services/quiz_ai_provider.dart';
import 'package:studymate/features/quizzes/viewmodels/quiz_viewmodel.dart';

void main() {
  test('sélection du fournisseur IA Gemini / OpenRouter', () {
    final vm = QuizViewModel(
      repository: QuizRepository.memory(quizzes: [], history: []),
      attemptRepository: MemoryQuizAttemptRepository(),
      geminiService: GeminiService(
        config: GeminiConfig(apiKey: '', proxyUrl: ''),
        client: MockClient((_) async => http.Response('{}', 200)),
      ),
      openRouterService: OpenRouterService(
        config: OpenRouterConfig(apiKey: '', proxyUrl: ''),
        client: MockClient((_) async => http.Response('{}', 200)),
      ),
    );

    expect(vm.selectedAiProvider, AiProviderKind.gemini);
    expect(vm.activeAiLabel, 'Gemini');
    expect(vm.activeAiConfigured, isFalse);

    vm.setAiProvider(AiProviderKind.openRouter);
    expect(vm.selectedAiProvider, AiProviderKind.openRouter);
    expect(vm.activeAiLabel, 'OpenRouter');
    expect(vm.openRouterConfigured, isFalse);
  });

  test('completeSession adapte la difficulté localement', () async {
    final quiz = Quiz(
      id: 'q1',
      title: 'T',
      description: 'D',
      subject: 'Java',
      difficulty: QuizDifficulty.moyen,
      estimatedMinutes: 5,
      questions: const [
        Question(id: '1', text: 'Q1', options: ['A', 'B', 'C', 'D'], correctIndex: 0),
        Question(id: '2', text: 'Q2', options: ['A', 'B', 'C', 'D'], correctIndex: 0),
      ],
    );

    final vm = QuizViewModel(
      repository: QuizRepository.memory(quizzes: [quiz], history: []),
      attemptRepository: MemoryQuizAttemptRepository(),
    );

    vm.startQuiz(quiz);
    vm.selectAnswer(1); // wrong
    vm.validateAnswer();
    vm.goToNextQuestion();
    vm.selectAnswer(1); // wrong
    vm.validateAnswer();

    final attempt = await vm.completeSession();
    expect(attempt, isNotNull);
    expect(attempt!.scorePercent, 0);
    expect(vm.suggestedDifficulty, QuizDifficulty.facile);
    expect(vm.aiDifficulty, QuizDifficulty.facile);
  });

  test('génération refuse sans config (aucun faux quiz)', () async {
    final vm = QuizViewModel(
      repository: QuizRepository.memory(quizzes: [], history: []),
      attemptRepository: MemoryQuizAttemptRepository(),
      geminiService: GeminiService(
        config: GeminiConfig(apiKey: '', proxyUrl: ''),
        client: MockClient((_) async => http.Response('{}', 200)),
      ),
    );
    vm.setAiTopic('Java collections');
    await vm.generateAiQuiz();
    expect(vm.generatedQuiz, isNull);
    expect(vm.errorMessage, isNotNull);
  });
}
