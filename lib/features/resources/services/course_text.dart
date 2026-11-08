import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class CourseText {
  static String fromPptx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final slides = archive.files.where((f) {
        final name = f.name.replaceAll('\\', '/').toLowerCase();
        return name.startsWith('ppt/slides/slide') && name.endsWith('.xml');
      }).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      final chunks = <String>[];
      final textTag = RegExp(r'<a:t[^>]*>([^<]*)</a:t>');
      for (final slide in slides) {
        final bytes = slide.readBytes();
        if (bytes == null || bytes.isEmpty) continue;
        final xml = utf8.decode(bytes, allowMalformed: true);
        final texts = textTag
            .allMatches(xml)
            .map((m) => _decodeXml(m.group(1) ?? '').trim())
            .where((t) => t.isNotEmpty);
        if (texts.isNotEmpty) chunks.add(texts.join(' '));
      }
      return chunks.join('\n');
    } catch (_) {
      return '';
    }
  }

  static String _decodeXml(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}
