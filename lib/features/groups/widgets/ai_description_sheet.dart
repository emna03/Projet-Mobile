import 'package:flutter/material.dart';

import '../../../core/config/gemini_config.dart';
import '../../../core/theme/app_theme.dart';
import '../services/gemini_description_service.dart';
import '../viewmodels/description_assistant_viewmodel.dart';

/// Opens the Gemini-powered description assistant.
///
/// Returns the description the user chose to keep, or `null` if dismissed.
Future<String?> showAiDescriptionSheet(
  BuildContext context, {
  required String groupName,
  required String level,
  required bool isPublic,
  required String currentDescription,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimensions.rCard),
      ),
    ),
    builder: (_) => AiDescriptionSheet(
      groupName: groupName,
      level: level,
      isPublic: isPublic,
      currentDescription: currentDescription,
    ),
  );
}

/// Small "Assistant IA" trigger placed under a description field.
class AiAssistButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AiAssistButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text('Rédiger avec l\'IA'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.primarySoft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.rButton),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class AiDescriptionSheet extends StatefulWidget {
  final String groupName;
  final String level;
  final bool isPublic;
  final String currentDescription;

  const AiDescriptionSheet({
    super.key,
    required this.groupName,
    required this.level,
    required this.isPublic,
    required this.currentDescription,
  });

  @override
  State<AiDescriptionSheet> createState() => _AiDescriptionSheetState();
}

class _AiDescriptionSheetState extends State<AiDescriptionSheet> {
  late final DescriptionAssistantViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = DescriptionAssistantViewModel(
      groupName: widget.groupName,
      level: widget.level,
      isPublic: widget.isPublic,
      currentDescription: widget.currentDescription,
    );
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(),
                const SizedBox(height: 20),
                if (!_vm.isConfigured)
                  _InfoBanner(
                    icon: Icons.key_off_outlined,
                    color: AppColors.accent,
                    message: 'Clé API Gemini non configurée. Renseignez-la '
                        'dans ${GeminiConfig.assetPath} puis relancez '
                        "complètement l'application (pas de hot reload).",
                  )
                else if (!_vm.hasGroupName)
                  const _InfoBanner(
                    icon: Icons.info_outline,
                    color: AppColors.primary,
                    message: "Saisissez d'abord le nom du groupe "
                        '(3 caractères minimum) pour guider l\'IA.',
                  ),
                if (!_vm.isConfigured || !_vm.hasGroupName)
                  const SizedBox(height: 16),
                _modeSelector(),
                const SizedBox(height: 18),
                _label('Ton'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: DescriptionTone.values
                      .map((t) => ChoiceChip(
                            label: Text(t.label),
                            selected: _vm.tone == t,
                            onSelected: _vm.isLoading
                                ? null
                                : (_) => _vm.setTone(t),
                          ))
                      .toList(),
                ),
                if (_vm.mode == AssistantMode.generate) ...[
                  const SizedBox(height: 18),
                  _label('Sujets à aborder (optionnel)'),
                  const SizedBox(height: 8),
                  TextField(
                    enabled: !_vm.isLoading,
                    maxLength: 120,
                    onChanged: _vm.setKeywords,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      counterText: '',
                      fillColor: AppColors.surfaceLight,
                      hintText: 'ex: JPA, sécurité, préparation aux examens',
                      prefixIcon:
                          Icon(Icons.label_outline, color: AppColors.muted),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed:
                      _vm.canSubmit && _vm.isConfigured ? _vm.submit : null,
                  icon: _vm.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _vm.suggestion == null
                              ? Icons.auto_awesome
                              : Icons.refresh,
                          size: 18,
                        ),
                  label: Text(_submitLabel()),
                ),
                if (_vm.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _InfoBanner(
                    icon: Icons.error_outline,
                    color: AppColors.danger,
                    message: _vm.errorMessage!,
                  ),
                ],
                if (_vm.suggestion != null) ...[
                  const SizedBox(height: 20),
                  _suggestionCard(_vm.suggestion!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _submitLabel() {
    if (_vm.isLoading) return 'Génération en cours...';
    if (_vm.suggestion != null) return 'Proposer une autre version';
    return _vm.mode == AssistantMode.generate
        ? 'Générer une description'
        : 'Améliorer la description';
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.auto_awesome, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assistant de description',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Propulsé par Google Gemini',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<AssistantMode>(
        showSelectedIcon: false,
        segments: [
          const ButtonSegment(
            value: AssistantMode.generate,
            label: Text('Générer'),
            icon: Icon(Icons.edit_note, size: 18),
          ),
          ButtonSegment(
            value: AssistantMode.improve,
            label: const Text('Améliorer'),
            icon: const Icon(Icons.auto_fix_high, size: 18),
            enabled: _vm.canImprove,
            tooltip: _vm.canImprove
                ? null
                : 'Rédigez au moins 10 caractères pour utiliser cette option',
          ),
        ],
        selected: {_vm.mode},
        onSelectionChanged:
            _vm.isLoading ? null : (s) => _vm.setMode(s.first),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      );

  Widget _suggestionCard(String suggestion) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.rButton),
        border: Border.all(color: AppColors.primarySoft, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _vm.modelUsed == null
                      ? 'Suggestion'
                      : 'Suggestion · ${_vm.modelUsed}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Text(
                '${suggestion.length}/${GeminiDescriptionService.maxLength}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            suggestion,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _vm.isLoading
                ? null
                : () => Navigator.pop(context, suggestion),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              minimumSize: const Size.fromHeight(46),
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Utiliser cette description'),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.rBadge),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}
