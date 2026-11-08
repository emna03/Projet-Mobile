import 'package:flutter/foundation.dart';

import '../../services/gemini_service.dart';
import '../../services/openrouter_service.dart';
import '../../services/quiz_ai_provider.dart';
import 'local_llm/kg_llm_config.dart';
import 'local_llm/local_knowledge_llm_service.dart';

typedef KnowledgeCompleter = Future<String> Function(String prompt);

/// Client d’extraction Knowledge Graph — **LLM local uniquement**.
///
/// Ne contacte plus Gemini / OpenRouter. Les paramètres [reconfigure] liés aux
/// configs Quiz sont ignorés (signature conservée pour ne pas casser Quiz).
class KnowledgeAiClient {
  KnowledgeAiClient({
    LocalKnowledgeLlmService? localLlm,
    Future<bool> Function()? availabilityProbe,
    KnowledgeCompleter? testCompleter,
    // Compat anciens constructeurs / Quiz — ignorés.
    GeminiConfig? geminiConfig,
    OpenRouterConfig? openRouterConfig,
    Object? client,
    AiProviderKind preferred = AiProviderKind.gemini,
  })  : preferred = preferred,
        _llmOrNull = localLlm,
        _availabilityProbe = availabilityProbe,
        _testCompleter = testCompleter;

  LocalKnowledgeLlmService? _llmOrNull;
  final Future<bool> Function()? _availabilityProbe;
  final KnowledgeCompleter? _testCompleter;
  AiProviderKind preferred;

  bool _available = false;
  String? lastFailureSummary;

  /// Lazy : évite d’instancier le plugin natif pendant les tests VM.
  LocalKnowledgeLlmService get localLlm =>
      _llmOrNull ??= LocalKnowledgeLlmService();

  /// true seulement si un GGUF valide est présent (ou probe de test).
  bool get isConfigured => _available;

  String get resolvedChannelLabel => _testCompleter != null
      ? 'test-double'
      : '${KgLlmConfig.engineLabel}/${KgLlmConfig.displayName}';

  Future<void> refreshAvailability() async {
    try {
      if (_availabilityProbe != null) {
        _available = await _availabilityProbe!();
      } else {
        _available = await localLlm.isConfigured;
      }
      if (!_available) {
        lastFailureSummary = (_llmOrNull?.modelManager.lastStatusMessage) ??
            'LLM local non disponible';
      }
    } catch (e) {
      _available = false;
      lastFailureSummary = e.toString();
    }
  }

  void reconfigure({
    GeminiConfig? geminiConfig,
    OpenRouterConfig? openRouterConfig,
    AiProviderKind? preferredProvider,
  }) {
    if (preferredProvider != null) preferred = preferredProvider;
    debugPrint(
      'KG AI: reconfigure cloud ignoré (LLM local — '
      '${KgLlmConfig.displayName})',
    );
  }

  Future<String> complete(String prompt) async {
    lastFailureSummary = null;
    await refreshAvailability();
    if (!_available) {
      lastFailureSummary = (_llmOrNull?.modelManager.lastStatusMessage) ??
          'Modèle LLM local non disponible';
      debugPrint('KG AI: $lastFailureSummary');
      throw StateError(lastFailureSummary ?? 'Modèle LLM local non disponible');
    }

    debugPrint(
      'KG AI: extraction via $resolvedChannelLabel '
      '(promptChars=${prompt.length})',
    );
    try {
      if (_testCompleter != null) {
        final text = await _testCompleter(prompt);
        debugPrint(
          'KG AI: OK via test-double (responseChars=${text.length})',
        );
        return text;
      }
      final text = await localLlm.complete(prompt);
      lastFailureSummary = null;
      return text;
    } catch (e) {
      lastFailureSummary = _llmOrNull?.lastFailureSummary ?? e.toString();
      debugPrint('KG AI: échec — $lastFailureSummary');
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_testCompleter == null && _llmOrNull != null) {
      await _llmOrNull!.unload();
    }
  }
}
