import 'package:flutter/foundation.dart';

import '../services/gemini_description_service.dart';

/// What the assistant should do with the description.
enum AssistantMode { generate, improve }

/// ViewModel behind the AI description assistant sheet.
///
/// Holds the generation options, the loading/error state and the latest
/// suggestion. The view only renders this state and forwards user intents.
class DescriptionAssistantViewModel extends ChangeNotifier {
  DescriptionAssistantViewModel({
    required this.groupName,
    required this.level,
    required this.isPublic,
    required this.currentDescription,
    GeminiDescriptionService? service,
  })  : _service = service ?? GeminiDescriptionService(),
        _ownsService = service == null,
        _mode = currentDescription.trim().length >=
                GeminiDescriptionService.minLength
            ? AssistantMode.improve
            : AssistantMode.generate;

  final String groupName;
  final String level;
  final bool isPublic;
  final String currentDescription;

  final GeminiDescriptionService _service;
  final bool _ownsService;

  // ─── State ─────────────────────────────────────────────────────────────────

  AssistantMode _mode;
  DescriptionTone _tone = DescriptionTone.professional;
  String _keywords = '';
  bool _isLoading = false;
  String? _suggestion;
  String? _errorMessage;
  bool _disposed = false;

  // ─── Getters ───────────────────────────────────────────────────────────────

  AssistantMode get mode => _mode;
  DescriptionTone get tone => _tone;
  String get keywords => _keywords;
  bool get isLoading => _isLoading;
  String? get suggestion => _suggestion;
  String? get errorMessage => _errorMessage;
  bool get isConfigured => _service.isConfigured;

  /// Gemini model that wrote the current [suggestion].
  String? get modelUsed => _service.lastModelUsed;

  bool get canImprove =>
      currentDescription.trim().length >= GeminiDescriptionService.minLength;

  /// Generation needs at least a meaningful group name to work from.
  bool get hasGroupName => groupName.trim().length >= 3;

  bool get canSubmit =>
      !_isLoading &&
      hasGroupName &&
      (_mode == AssistantMode.generate || canImprove);

  // ─── Intents ───────────────────────────────────────────────────────────────

  void setMode(AssistantMode mode) {
    if (mode == AssistantMode.improve && !canImprove) return;
    _mode = mode;
    _notify();
  }

  void setTone(DescriptionTone tone) {
    _tone = tone;
    _notify();
  }

  void setKeywords(String value) {
    _keywords = value;
  }

  Future<void> submit() async {
    if (!canSubmit) return;
    _isLoading = true;
    _errorMessage = null;
    _notify();

    try {
      _suggestion = switch (_mode) {
        AssistantMode.generate => await _service.generateDescription(
            groupName: groupName.trim(),
            level: level,
            isPublic: isPublic,
            keywords: _keywords,
            tone: _tone,
          ),
        AssistantMode.improve => await _service.improveDescription(
            groupName: groupName.trim(),
            level: level,
            currentDescription: currentDescription,
            tone: _tone,
          ),
      };
    } on GeminiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Une erreur inattendue est survenue. Réessayez.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_ownsService) _service.dispose();
    super.dispose();
  }
}
