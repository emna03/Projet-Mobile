import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Normalisation / déduplication déterministe des libellés de concepts.
class ConceptNormalizer {
  const ConceptNormalizer();

  /// Forme canonique : minuscules, sans accents, espaces réduits.
  String canonicalize(String raw) {
    var s = raw.trim().toLowerCase();
    const map = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'á': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'œ': 'oe',
    };
    for (final e in map.entries) {
      s = s.replaceAll(e.key, e.value);
    }
    s = s.replaceAll(RegExp(r'[^a-z0-9\s\-+/]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  String conceptIdFromCanonical(String canonical) {
    final digest = sha1.convert(utf8.encode('kg:$canonical')).toString();
    return 'c-${digest.substring(0, 16)}';
  }

  String displayName(String raw) {
    final t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  /// Hash stable du contenu d’un quiz pour le cache d’extraction.
  String contentHash({
    required String quizId,
    required List<({String id, String text, String explanation})> questions,
  }) {
    final buf = StringBuffer(quizId);
    for (final q in questions) {
      buf.write('|');
      buf.write(q.id);
      buf.write(':');
      buf.write(canonicalize(q.text));
      buf.write('#');
      buf.write(canonicalize(q.explanation));
    }
    return sha1.convert(utf8.encode(buf.toString())).toString();
  }
}
