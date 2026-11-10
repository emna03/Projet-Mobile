import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

import 'kg_llm_config.dart';
import 'local_model_manager.dart';

/// Factory de stream de tokens (tests / injection).
typedef KgLlmGenerateStream = Stream<String> Function({
  required String prompt,
  required int maxTokens,
  required double temperature,
});

/// Inférence LLM locale (llama.cpp) pour l’extraction Knowledge Graph.
///
/// Aucun appel HTTP. Android + fichier GGUF requis.
/// Les appels sont **sérialisés** pour éviter « Model already loaded »
/// / « Model not loaded » / « Already generating ».
class LocalKnowledgeLlmService {
  LocalKnowledgeLlmService({
    LocalModelManager? modelManager,
    LlamaController? controller,
    this.inferenceTimeout = defaultInferenceTimeout,
    @visibleForTesting this._generateStreamOverride,
  })  : _models = modelManager ?? LocalModelManager(),
        _injectedController = controller;

  /// Délai max d’une génération (stream natif qui ne se ferme jamais).
  /// ~320 tokens @ 0.5B Q4 sur téléphone milieu de gamme.
  static const Duration defaultInferenceTimeout = Duration(seconds: 90);

  final LocalModelManager _models;
  final LlamaController? _injectedController;
  final KgLlmGenerateStream? _generateStreamOverride;
  final Duration inferenceTimeout;
  LlamaController? _ownedController;

  bool _loaded = false;
  String? lastFailureSummary;
  double loadProgress = 0;

  /// File d’attente : un seul load/generate à la fois.
  Future<void> _gate = Future<void>.value();

  LocalModelManager get modelManager => _models;

  bool get isModelLoaded => _loaded;

  /// true quand le verrou sérialisé est libre (tests / diagnostic).
  bool get isInferenceGateIdle => _activeSerialized == 0;

  int _activeSerialized = 0;

  LlamaController get _controller {
    final injected = _injectedController;
    if (injected != null) return injected;
    return _ownedController ??= LlamaController();
  }

  Future<bool> get isConfigured async => _models.isModelAvailable();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final starter = Completer<void>();
    final previous = _gate;
    _gate = starter.future;
    return previous.catchError((_) {}).then((_) async {
      _activeSerialized++;
      try {
        return await action();
      } finally {
        _activeSerialized--;
      }
    }).whenComplete(() {
      if (!starter.isCompleted) starter.complete();
    });
  }

  Future<bool> _nativeIsLoaded() async {
    try {
      return await _controller.isModelLoaded();
    } catch (e) {
      debugPrint('KG local LLM: isModelLoaded échoué — ${_sanitize('$e')}');
      return false;
    }
  }

  /// `LlamaController.loadModel` lève `StateError('Model already loaded')`
  /// (toString → `Bad state: Model already loaded`) si le natif a déjà le GGUF.
  @visibleForTesting
  static bool isAlreadyLoadedError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('already loaded')) return true;
    if (s.contains('model already')) return true;
    // Filet de sécurité : toute variante « already » + « load ».
    return s.contains('already') && s.contains('load');
  }

  static bool _isAlreadyLoadingError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('already loading');
  }

  static bool _isNotLoadedError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('not loaded') || s.contains('model not loaded');
  }

  static bool _isAlreadyGeneratingError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('already generating');
  }

  /// Dispose le controller Dart (après dispose() il n’est plus réutilisable).
  Future<void> _resetController() async {
    await _stopNativeGeneration();
    final c = _injectedController ?? _ownedController;
    if (c != null) {
      try {
        await c.dispose().timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('KG local LLM: reset dispose — ${_sanitize('$e')}');
      }
    }
    if (_injectedController == null) {
      _ownedController = null;
    }
    _loaded = false;
    loadProgress = 0;
  }

  /// Charge le GGUF si besoin. Idempotent : « already loaded » = succès.
  Future<void> ensureLoaded() async {
    lastFailureSummary = null;
    if (!await _models.isModelAvailable()) {
      lastFailureSummary = _models.lastStatusMessage ?? 'modèle absent';
      throw StateError(lastFailureSummary!);
    }

    // 1) Déjà OK côté Dart + natif.
    if (_loaded && await _nativeIsLoaded()) {
      loadProgress = 1;
      return;
    }

    // 2) Natif déjà chargé (ex. ✨ précédent, timeout, hot restart) → ne PAS
    //    rappeler loadModel : le plugin lève StateError('Model already loaded').
    if (await _nativeIsLoaded()) {
      _loaded = true;
      loadProgress = 1;
      debugPrint('KG local LLM: modèle déjà chargé (natif) — skip loadModel');
      return;
    }

    // 3) Désync : Dart croyait chargé, natif non → reset puis reload.
    if (_loaded) {
      debugPrint('KG local LLM: désync Dart/natif — reset puis reload');
      await _resetController();
    }

    await _loadModelFresh();
  }

  Future<void> _loadModelFresh() async {
    // Double-check immédiat avant l’appel plugin (évite la course).
    if (await _nativeIsLoaded()) {
      _loaded = true;
      loadProgress = 1;
      return;
    }

    final path = _models.cachedPath ?? await _models.expectedModelPath();
    debugPrint(
      'KG local LLM: chargement ${KgLlmConfig.displayName} '
      '(${KgLlmConfig.quantization})…',
    );

    StreamSubscription<double>? progressSub;
    try {
      progressSub = _controller.loadProgress.listen((p) {
        loadProgress = p;
      });

      await _controller.loadModel(
        modelPath: path,
        threads: KgLlmConfig.threads,
        contextSize: KgLlmConfig.contextSize,
        gpuLayers: 0,
      );
      _loaded = true;
      loadProgress = 1;
      lastFailureSummary = null;
      debugPrint('KG local LLM: modèle chargé ($path)');
    } catch (e) {
      // Cas nominal du plugin quand isModelLoaded a menti / course :
      // StateError('Model already loaded') → succès, pas un échec utilisateur.
      if (isAlreadyLoadedError(e) || await _nativeIsLoaded()) {
        _loaded = true;
        loadProgress = 1;
        lastFailureSummary = null;
        debugPrint(
          'KG local LLM: already loaded (plugin) — traité comme succès',
        );
        return;
      }

      if (_isAlreadyLoadingError(e)) {
        debugPrint('KG local LLM: already loading — attente courte');
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (await _nativeIsLoaded()) {
          _loaded = true;
          loadProgress = 1;
          lastFailureSummary = null;
          return;
        }
      }

      _loaded = false;
      lastFailureSummary = _sanitize('load: $e');
      debugPrint('KG local LLM: échec chargement — $lastFailureSummary');
      rethrow;
    } finally {
      try {
        await progressSub?.cancel();
      } catch (_) {}
    }
  }

  Future<String> complete(String prompt) {
    return _serialized(() => _completeBody(prompt));
  }

  Future<String> _completeBody(String prompt) async {
    lastFailureSummary = null;
    // Chemin test : stream injecté → pas de load natif GGUF.
    if (_generateStreamOverride != null) {
      _loaded = true;
    } else {
      await ensureLoaded();
    }

    try {
      return await _generateOnce(prompt);
    } catch (e) {
      if (_isNotLoadedError(e) || _isAlreadyGeneratingError(e)) {
        debugPrint(
          'KG local LLM: état natif invalide ($e) — reset + retry',
        );
        if (_generateStreamOverride != null) rethrow;
        await _resetController();
        await ensureLoaded();
        return _generateOnce(prompt);
      }
      rethrow;
    }
  }

  Stream<String> _openGenerateStream(String prompt) {
    final override = _generateStreamOverride;
    if (override != null) {
      return override(
        prompt: prompt,
        maxTokens: KgLlmConfig.maxTokens,
        temperature: KgLlmConfig.temperature,
      );
    }
    // Qwen2.5-Instruct : ChatML via generateChat (évite l’écho de prompt brut).
    return _controller.generateChat(
      messages: [
        ChatMessage(role: 'system', content: KgLlmConfig.systemPrompt),
        ChatMessage(role: 'user', content: prompt),
      ],
      template: KgLlmConfig.chatTemplate,
      maxTokens: KgLlmConfig.maxTokens,
      temperature: KgLlmConfig.temperature,
      topP: KgLlmConfig.topP,
      topK: KgLlmConfig.topK,
      repeatPenalty: KgLlmConfig.repeatPenalty,
    );
  }

  /// Stop natif sans créer de controller si aucun n’existe encore.
  Future<void> _stopNativeGeneration() async {
    final c = _injectedController ?? _ownedController;
    if (c == null) return;
    try {
      if (c.isGenerating) {
        await c.stop().timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint(
        'KG local LLM: stop après timeout/erreur — ${_sanitize('$e')}',
      );
    }
  }

  Future<String> _generateOnce(String prompt) async {
    final buffer = StringBuffer();
    final done = Completer<void>();
    Object? error;
    var settled = false;

    void settle([Object? err]) {
      if (settled) return;
      settled = true;
      if (err != null) error = err;
      if (!done.isCompleted) done.complete();
    }

    // Évite « Already generating » si un précédent stream n’a pas reçu onDone
    // (timeout, crash ADB, stop partiel).
    await _stopNativeGeneration();

    debugPrint(
      'KG local LLM: [gen] start promptChars=${prompt.length} '
      'maxTokens=${KgLlmConfig.maxTokens} temp=${KgLlmConfig.temperature} '
      'template=${KgLlmConfig.chatTemplate} '
      'timeout=${inferenceTimeout.inSeconds}s',
    );

    late final StreamSubscription<String> sub;
    sub = _openGenerateStream(prompt).listen(
      (chunk) {
        if (settled) return;
        buffer.write(chunk);
      },
      onError: (Object e, StackTrace st) {
        settle(e);
      },
      onDone: () {
        settle();
      },
      cancelOnError: true,
    );

    try {
      await done.future.timeout(inferenceTimeout);
    } on TimeoutException {
      settle(StateError('infer: timeout'));
      try {
        await sub.cancel();
      } catch (_) {}
      await _stopNativeGeneration();
      lastFailureSummary = _sanitize('infer: timeout');
      debugPrint('KG local LLM: [gen] FAIL $lastFailureSummary');
      throw StateError(lastFailureSummary!);
    }

    try {
      await sub.cancel();
    } catch (_) {}

    if (error != null) {
      lastFailureSummary = _sanitize('infer: $error');
      debugPrint('KG local LLM: [gen] FAIL $lastFailureSummary');
      throw StateError(lastFailureSummary!);
    }

    final text = buffer.toString().trim();
    if (text.isEmpty) {
      lastFailureSummary = 'réponse LLM locale vide';
      debugPrint('KG local LLM: [gen] FAIL $lastFailureSummary');
      throw StateError(lastFailureSummary!);
    }

    // Libère le KV-cache entre quiz (générations successives).
    try {
      final c = _injectedController ?? _ownedController;
      if (c != null) await c.clearContext();
    } catch (e) {
      debugPrint('KG local LLM: clearContext — ${_sanitize('$e')}');
    }

    final preview = text.length <= 180 ? text : '${text.substring(0, 180)}…';
    debugPrint(
      'KG local LLM: [gen] OK responseChars=${text.length} preview=$preview',
    );
    return text;
  }

  Future<void> unload() async {
    await _serialized(() async {
      try {
        await _resetController();
      } catch (e) {
        debugPrint('KG local LLM: unload — ${_sanitize('$e')}');
        _ownedController = null;
        _loaded = false;
        loadProgress = 0;
      }
    });
  }

  static String _sanitize(String raw) {
    return raw
        .replaceAll(RegExp(r'key=[^&\s"]+', caseSensitive: false), 'key=***')
        .replaceAll(
          RegExp(r'Bearer\s+\S+', caseSensitive: false),
          'Bearer ***',
        );
  }

  static bool get canRunNativeInference {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }
}
