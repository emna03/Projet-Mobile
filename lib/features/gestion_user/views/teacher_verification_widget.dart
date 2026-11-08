
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

class TeacherVerificationWidget extends StatelessWidget {
  final String? documentPath;
  final String extractedText;
  final bool isReading;
  final VoidCallback onSelectDocument;

  const TeacherVerificationWidget({
    super.key,
    required this.documentPath,
    required this.extractedText,
    required this.isReading,
    required this.onSelectDocument,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Vérification de l’enseignant', style: SM.h(17)),
        const SizedBox(height: 8),
        Text(
          'Ajoute une attestation de travail, une carte '
          'professionnelle ou un autre justificatif accepté.',
          style: SM.b(13, color: SM.muted),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: isReading ? null : onSelectDocument,
          icon: isReading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(LucideIcons.fileUp),
          label: Text(
            isReading
                ? 'Lecture en cours...'
                : documentPath == null
                    ? 'Ajouter un justificatif'
                    : 'Changer le document',
          ),
        ),
        if (documentPath != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(SM.rButton),
            child: Image.file(
              File(documentPath!),
              height: 160,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Document ajouté',
            style: SM.b(13, color: SM.success),
          ),
        ],
        if (extractedText.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Texte détecté par OCR',
            style: SM.b(14, w: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SM.primarySoft,
              borderRadius: BorderRadius.circular(SM.rButton),
            ),
            child: SelectableText(
              extractedText,
              style: SM.b(13),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Ton compte enseignant devra être vérifié avant '
          'd’obtenir les droits réservés aux enseignants.',
          style: SM.b(12, color: SM.muted),
        ),
      ],
    );
  }
}
