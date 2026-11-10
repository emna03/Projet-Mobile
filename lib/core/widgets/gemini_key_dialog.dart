import 'package:flutter/material.dart';

import '../config/gemini_config.dart';
import '../theme/app_theme.dart';

/// Vérifie qu'une clé Gemini est disponible ; sinon, la demande à
/// l'utilisateur (gardée en mémoire pour la session seulement).
///
/// Partagé par les ressources (résumé, flashcards) et les groupes
/// (assistant de description).
Future<bool> ensureGeminiKey(
  BuildContext context, {
  String reason =
      'Les fonctions IA de StudyMate utilisent Gemini. Collez votre clé (Google AI Studio).',
}) async {
  if (GeminiConfig.isEnabled) return true;
  final key = await showDialog<String>(
    context: context,
    builder: (_) => _GeminiKeyDialog(reason: reason),
  );
  if (key == null || key.trim().isEmpty) return false;
  GeminiConfig.sessionApiKey = key.trim();
  return true;
}

/// Le dialogue possède son propre [TextEditingController] et ne le libère
/// qu'à sa destruction, APRÈS l'animation de fermeture.
///
/// Correction : l'ancien code appelait `controller.dispose()` dès le retour
/// de `showDialog`, alors que le champ était encore affiché pendant
/// l'animation de sortie → écran rouge « '_dependents.isEmpty': is not true »
/// à la première saisie de la clé.
class _GeminiKeyDialog extends StatefulWidget {
  final String reason;
  const _GeminiKeyDialog({required this.reason});

  @override
  State<_GeminiKeyDialog> createState() => _GeminiKeyDialogState();
}

class _GeminiKeyDialogState extends State<_GeminiKeyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Clé API Gemini', style: SM.h(18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.reason, style: SM.b(14)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Clé API'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
