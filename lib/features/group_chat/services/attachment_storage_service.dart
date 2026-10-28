import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages local file storage for group chat attachments.
///
/// Files are stored in [getApplicationDocumentsDirectory]/studymate_attachments/
/// so they persist across app restarts and are not cleared with the cache.
///
/// SQLite stores only the relative path (relative to the documents dir root).
/// This keeps paths stable even if the absolute path changes between installs.
class AttachmentStorageService {
  static const _subDir = 'studymate_attachments';
  static const maxFileSizeBytes = 20 * 1024 * 1024; // 20 MB

  static const allowedMimeTypes = <String>[
    'application/pdf',
    'image/jpeg',
    'image/jpg',
    'image/png',
    'text/plain',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ];

  static const allowedExtensions = <String>[
    'pdf', 'jpg', 'jpeg', 'png', 'txt',
    'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx',
  ];

  /// Resolves the base documents directory.
  Future<Directory> _getBaseDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docsDir.path, _subDir));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Converts a relative path (stored in SQLite) to an absolute [File].
  Future<File> resolveFile(String relativePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File(p.join(docsDir.path, relativePath));
  }

  /// Copies the file at [sourcePath] into the managed storage directory.
  ///
  /// Returns a tuple of (relativePath, mimeType) or throws on error.
  Future<({String relativePath, String mimeType, int fileSize})>
      storeFile(String sourcePath, String groupId) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw Exception('Le fichier source est introuvable.');
    }

    final size = await source.length();
    if (size > maxFileSizeBytes) {
      throw Exception(
          'La taille du fichier dépasse la limite autorisée (20 Mo).');
    }

    final ext = p.extension(sourcePath).replaceFirst('.', '').toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      throw Exception('Type de fichier non autorisé : .$ext');
    }

    final baseDir = await _getBaseDir();
    final groupDir = Directory(p.join(baseDir.path, groupId));
    if (!groupDir.existsSync()) {
      await groupDir.create(recursive: true);
    }

    final filename =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
    final destPath = p.join(groupDir.path, filename);
    await source.copy(destPath);

    // Relative to docs dir
    final docsDir = await getApplicationDocumentsDirectory();
    final relative = p.relative(destPath, from: docsDir.path);

    return (
      relativePath: relative,
      mimeType: _mimeFromExt(ext),
      fileSize: size,
    );
  }

  /// Deletes the file at the given relative path. Silently ignores missing files.
  Future<void> deleteFile(String relativePath) async {
    try {
      final file = await resolveFile(relativePath);
      if (file.existsSync()) await file.delete();
    } catch (e) {
      debugPrint('AttachmentStorageService.deleteFile error: $e');
    }
  }

  /// Returns true if the file at [relativePath] exists on disk.
  Future<bool> fileExists(String relativePath) async {
    try {
      final file = await resolveFile(relativePath);
      return file.existsSync();
    } catch (_) {
      return false;
    }
  }

  String _mimeFromExt(String ext) {
    const map = {
      'pdf': 'application/pdf',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'txt': 'text/plain',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    };
    return map[ext] ?? 'application/octet-stream';
  }
}
