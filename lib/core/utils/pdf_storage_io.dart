import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PdfStorage {
  static const allowedExtensions = ['pdf', 'ppt', 'pptx'];

  static bool isAllowed(String name) {
    final lower = name.toLowerCase();
    return allowedExtensions.any((ext) => lower.endsWith('.$ext'));
  }

  static Future<({String path, String name, Uint8List bytes})?> save(PlatformFile file) async {
    final name = file.name;
    if (!isAllowed(name)) return null;

    final docs = await getApplicationDocumentsDirectory();
    final destDir = Directory(p.join(docs.path, 'resource_files'));
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final safeName = name.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final dest = p.join(destDir.path, '${DateTime.now().millisecondsSinceEpoch}_$safeName');

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    await File(dest).writeAsBytes(bytes);
    return (path: dest, name: name, bytes: bytes);
  }

  static Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static Future<Uint8List?> readBytes(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  static Future<bool> exists(String? path, {Uint8List? bytes}) async {
    if (bytes != null && bytes.isNotEmpty) return true;
    if (path == null || path.isEmpty) return false;
    return File(path).exists();
  }

  static Future<String?> open({
    required String name,
    String? path,
    Uint8List? bytes,
    required String mime,
  }) async {
    var filePath = path;
    if (filePath == null || filePath.isEmpty || !await File(filePath).exists()) {
      if (bytes == null || bytes.isEmpty) {
        return 'Le fichier n’est plus disponible. Modifiez la ressource et joignez-le à nouveau.';
      }
      final tmp = await getTemporaryDirectory();
      final safeName = name.replaceAll(RegExp(r'[^\w.\-]+'), '_');
      filePath = p.join(tmp.path, safeName);
      await File(filePath).writeAsBytes(bytes, flush: true);
    }
    final result = await OpenFilex.open(filePath, type: mime);
    if (result.type == ResultType.done) return null;
    return result.message;
  }
}
