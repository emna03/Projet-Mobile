import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;

class PdfStorage {
  static const allowedExtensions = ['pdf', 'ppt', 'pptx'];

  static bool isAllowed(String name) {
    final lower = name.toLowerCase();
    return allowedExtensions.any((ext) => lower.endsWith('.$ext'));
  }

  static Future<({String path, String name, Uint8List bytes})?> save(PlatformFile file) async {
    if (!isAllowed(file.name)) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    return (path: '', name: file.name, bytes: bytes);
  }

  static Future<void> delete(String? path) async {}

  static Future<Uint8List?> readBytes(String? path) async => null;

  static Future<bool> exists(String? path, {Uint8List? bytes}) async =>
      bytes != null && bytes.isNotEmpty;

  static Future<String?> open({
    required String name,
    String? path,
    Uint8List? bytes,
    required String mime,
  }) async {
    if (bytes == null || bytes.isEmpty) {
      return 'Le fichier n’est plus disponible. Modifiez la ressource et joignez-le à nouveau.';
    }
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mime),
    );
    final url = web.URL.createObjectURL(blob);
    final isPdf = name.toLowerCase().endsWith('.pdf');
    if (isPdf) {
      web.window.open(url, '_blank');
    } else {
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..download = name;
      web.document.body?.appendChild(anchor);
      anchor.click();
      anchor.remove();
    }
    unawaited(Future<void>.delayed(const Duration(seconds: 30), () {
      web.URL.revokeObjectURL(url);
    }));
    return null;
  }
}
