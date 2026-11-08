import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/quizzes/services/gemini_service.dart';
import 'package:studymate/features/quizzes/services/openrouter_service.dart';
import 'package:studymate/features/quizzes/services/quiz_ai_credential_store.dart';

class _MemoryVault implements QuizAiSecureVault {
  final Map<String, String> values = {};

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

void main() {
  test('clé vide ⇒ Gemini et OpenRouter non configurés', () {
    const empty = QuizAiResolvedCredentials.empty;
    expect(empty.geminiConfigured, isFalse);
    expect(empty.openRouterConfigured, isFalse);

    final gemini = GeminiConfig(apiKey: '', proxyUrl: '');
    final openRouter = OpenRouterConfig(apiKey: '', proxyUrl: '');
    expect(gemini.isConfigured, isFalse);
    expect(openRouter.isConfigured, isFalse);
  });

  test('statut Gemini et OpenRouter calculés séparément', () {
    const onlyGemini = QuizAiResolvedCredentials(
      geminiApiKey: 'test-gemini-key-not-real',
      geminiProxyUrl: '',
      geminiModel: 'gemini-flash-lite-latest',
      openRouterApiKey: '',
      openRouterProxyUrl: '',
      openRouterModel: '',
    );
    expect(onlyGemini.geminiConfigured, isTrue);
    expect(onlyGemini.openRouterConfigured, isFalse);

    const onlyOpenRouter = QuizAiResolvedCredentials(
      geminiApiKey: '',
      geminiProxyUrl: '',
      geminiModel: '',
      openRouterApiKey: 'test-openrouter-key-not-real',
      openRouterProxyUrl: '',
      openRouterModel: 'google/gemma-4-31b-it:free',
    );
    expect(onlyOpenRouter.geminiConfigured, isFalse);
    expect(onlyOpenRouter.openRouterConfigured, isTrue);
  });

  test('dart-define non vide est persisté puis relu sans redefine', () async {
    final vault = _MemoryVault();
    final store = QuizAiCredentialStore(vault: vault);

    final first = await store.resolveAndMaybePersist(
      compileOverride: const QuizAiResolvedCredentials(
        geminiApiKey: 'compile-gemini',
        geminiProxyUrl: '',
        geminiModel: 'gemini-flash-lite-latest',
        openRouterApiKey: 'compile-openrouter',
        openRouterProxyUrl: '',
        openRouterModel: 'google/gemma-4-31b-it:free',
      ),
    );
    expect(first.geminiConfigured, isTrue);
    expect(first.openRouterConfigured, isTrue);
    expect(vault.values.containsKey('quiz_ai.gemini.api_key'), isTrue);
    expect(vault.values.containsKey('quiz_ai.openrouter.api_key'), isTrue);

    final second = await store.resolveAndMaybePersist(
      compileOverride: QuizAiResolvedCredentials.empty,
      persist: false,
    );
    expect(second.geminiApiKey, 'compile-gemini');
    expect(second.openRouterApiKey, 'compile-openrouter');
    expect(second.geminiConfigured, isTrue);
    expect(second.openRouterConfigured, isTrue);
  });

  test('compile-time prioritaire sur le stockage ; vide ne remplace pas',
      () async {
    final vault = _MemoryVault();
    final store = QuizAiCredentialStore(vault: vault);

    await store.resolveAndMaybePersist(
      compileOverride: const QuizAiResolvedCredentials(
        geminiApiKey: 'stored-gemini',
        geminiProxyUrl: '',
        geminiModel: 'm1',
        openRouterApiKey: 'stored-or',
        openRouterProxyUrl: '',
        openRouterModel: 'm2',
      ),
    );

    final merged = await store.resolveAndMaybePersist(
      compileOverride: const QuizAiResolvedCredentials(
        geminiApiKey: 'fresh-gemini',
        geminiProxyUrl: '',
        geminiModel: 'm3',
        openRouterApiKey: '',
        openRouterProxyUrl: '',
        openRouterModel: '',
      ),
      persist: false,
    );

    expect(merged.geminiApiKey, 'fresh-gemini');
    expect(merged.openRouterApiKey, 'stored-or');
  });

  test('reconfigure des services met à jour isConfigured', () {
    final gemini = GeminiService(config: GeminiConfig(apiKey: '', proxyUrl: ''));
    final openRouter =
        OpenRouterService(config: OpenRouterConfig(apiKey: '', proxyUrl: ''));
    expect(gemini.isConfigured, isFalse);
    expect(openRouter.isConfigured, isFalse);

    gemini.reconfigure(GeminiConfig(apiKey: 'k-gemini', proxyUrl: ''));
    openRouter.reconfigure(OpenRouterConfig(apiKey: 'k-or', proxyUrl: ''));
    expect(gemini.isConfigured, isTrue);
    expect(openRouter.isConfigured, isTrue);

    gemini.reconfigure(GeminiConfig(apiKey: '', proxyUrl: ''));
    expect(gemini.isConfigured, isFalse);
  });

  test('saveKeyIfAbsent n’écrase pas une clé déjà présente', () async {
    final vault = _MemoryVault();
    final store = QuizAiCredentialStore(vault: vault);

    final first = await store.saveKeyIfAbsent(
      gemini: true,
      raw: 'AIzaSyDummyGeminiKeyForUnitTest123456',
    );
    expect(first, isTrue);
    final original = vault.values['quiz_ai.gemini.api_key'];

    final second = await store.saveKeyIfAbsent(
      gemini: true,
      raw: 'AIzaSyAnotherGeminiKeyShouldNotReplace999',
    );
    expect(second, isTrue);
    expect(vault.values['quiz_ai.gemini.api_key'], original);
  });

  test('extractApiToken refuse vide et mélange fournisseurs', () {
    expect(
      QuizAiCredentialStore.extractApiToken('', gemini: true),
      isNull,
    );
    expect(
      QuizAiCredentialStore.extractApiToken(
        'sk-or-v1-aaaaaaaaaaaaaaaaaaaaaaaa',
        gemini: true,
      ),
      isNull,
    );
    expect(
      QuizAiCredentialStore.extractApiToken(
        'AIzaSyDummyGeminiKeyForUnitTest123456',
        gemini: false,
      ),
      isNull,
    );
  });
}
