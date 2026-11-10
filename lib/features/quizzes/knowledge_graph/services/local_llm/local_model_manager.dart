import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'kg_llm_config.dart';

/// Cycle de vie du fichier GGUF Knowledge Graph (présence / chemins / taille).
class LocalModelManager {
  LocalModelManager({
    Directory? overrideDirectory,
    String? overrideFileName,
  })  : _overrideDirectory = overrideDirectory,
        _fileName = overrideFileName ?? KgLlmConfig.fileName;

  final Directory? _overrideDirectory;
  final String _fileName;

  String? _cachedPath;
  String? lastStatusMessage;

  /// Android uniquement pour l’inférence native actuelle.
  bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || _overrideDirectory != null);

  Future<Directory> modelDirectory() async {
    if (_overrideDirectory != null) return _overrideDirectory!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, KgLlmConfig.documentsSubdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> expectedModelPath() async {
    final dir = await modelDirectory();
    return p.join(dir.path, _fileName);
  }

  /// Vérifie présence + taille plausible. Ne télécharge rien.
  Future<bool> isModelAvailable() async {
    if (!isSupportedPlatform) {
      lastStatusMessage =
          'LLM local Knowledge Graph : plateforme non supportée '
          '(Android requis).';
      _cachedPath = null;
      return false;
    }
    final path = await expectedModelPath();
    final file = File(path);
    if (!await file.exists()) {
      lastStatusMessage =
          'Modèle absent. Placez « ${_fileName} » dans '
          '${await modelDirectory().then((d) => d.path)} '
          '(voir MODEL_INSTALL.md).';
      _cachedPath = null;
      return false;
    }
    final len = await file.length();
    if (len < KgLlmConfig.expectedMinBytes ||
        len > KgLlmConfig.expectedMaxBytes) {
      lastStatusMessage =
          'Fichier modèle de taille inattendue ($len octets). '
          'Attendu ~491 Mo (${KgLlmConfig.quantization}).';
      _cachedPath = null;
      return false;
    }
    _cachedPath = path;
    lastStatusMessage =
        'Modèle prêt : ${KgLlmConfig.displayName} ${KgLlmConfig.quantization}';
    return true;
  }

  String? get cachedPath => _cachedPath;

  Future<int?> availableDiskBytes() async {
    try {
      final dir = await modelDirectory();
      // StatFS non portable en pure Dart — on reporte null si indisponible.
      final stat = await dir.stat();
      return stat.size >= 0 ? null : null;
    } catch (_) {
      return null;
    }
  }
}
