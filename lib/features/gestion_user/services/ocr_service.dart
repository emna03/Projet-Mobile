
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class OcrDocumentResult {
  final String path;
  final String extractedText;
  final bool isLikelyTeacherDocument;
  final String message;

  const OcrDocumentResult({
    required this.path,
    required this.extractedText,
    required this.isLikelyTeacherDocument,
    required this.message,
  });
}

class OcrService {
  final ImagePicker _picker = ImagePicker();

  // Catégories d'indices : les mots d'une même catégorie
  // ne sont pas comptés comme des preuves indépendantes.
  static const List<List<String>> _keywordGroups = [
    [
      'enseignant',
      'enseignante',
      'professeur',
      'professeure',
      'teacher',
      'lecturer',
      'professor',
    ],
    [
      'attestation de travail',
      'attestation d emploi',
      'certificat de travail',
      'employment certificate',
    ],
    [
      'carte professionnelle',
      'carte professionnelle enseignant',
      'professional card',
    ],
    [
      'doctorant',
      'doctorante',
      'phd student',
    ],
    [
      'carte etudiant',
      'carte d etudiant',
      'student card',
    ],
    [
      'universite',
      'university',
      'faculte',
      'faculty',
      'institut superieur',
    ],
    [
      'ministere de l education',
      'ministere de l enseignement',
    ],
  ];

  Future<OcrDocumentResult?> pickAndRead(
    BuildContext context,
  ) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(
                sheetContext,
                ImageSource.camera,
              ),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(
                sheetContext,
                ImageSource.gallery,
              ),
            ),
          ],
        ),
      ),
    );

    if (source == null) return null;

    final image = await _picker.pickImage(
      source: source,
      imageQuality: 90,
    );

    if (image == null) return null;

    final recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(image.path),
      );

      final extractedText = result.text.trim();
      final normalizedText = _normalize(extractedText);

      if (normalizedText.isEmpty) {
        return OcrDocumentResult(
          path: image.path,
          extractedText: extractedText,
          isLikelyTeacherDocument: false,
          message:
              'Aucun texte lisible détecté. '
              'Essaie avec une image plus nette.',
        );
      }

      final matchedGroups = _keywordGroups.where((group) {
        return group.any(
          (keyword) => normalizedText.contains(
            _normalize(keyword),
          ),
        );
      }).length;

      // Filtre préliminaire : au moins deux catégories d'indices.
      // Cela ne confirme ni le rôle réel ni l'authenticité du document.
      final accepted = matchedGroups >= 2;

      return OcrDocumentResult(
        path: image.path,
        extractedText: extractedText,
        isLikelyTeacherDocument: accepted,
        message: accepted
            ? 'Le document contient suffisamment d’indices '
                'pour poursuivre l’inscription automatique.'
            : 'Le document n’a pas été reconnu. Vérifie sa '
                'lisibilité et utilise un justificatif adapté.',
      );
    } finally {
      await recognizer.close();
    }
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâ]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
