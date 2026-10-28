import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/chat_message.dart';
import '../services/attachment_storage_service.dart';
import '../viewmodels/group_chat_viewmodel.dart';

/// Card widget showing metadata and actions for a file attachment.
class AttachmentCard extends StatefulWidget {
  final ChatAttachment attachment;
  final GroupChatViewModel viewModel;
  final bool isMe;

  const AttachmentCard({
    super.key,
    required this.attachment,
    required this.viewModel,
    required this.isMe,
  });

  @override
  State<AttachmentCard> createState() => _AttachmentCardState();
}

class _AttachmentCardState extends State<AttachmentCard> {
  File? _imageFile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolveFile();
  }

  Future<void> _resolveFile() async {
    try {
      final storage = AttachmentStorageService();
      final file = await storage.resolveFile(widget.attachment.localPath);
      if (mounted) {
        setState(() {
          _imageFile = file.existsSync() ? file : null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attachment.isImage && !_loading && _imageFile != null) {
      return _ImageAttachment(
        file: _imageFile!,
        attachment: widget.attachment,
        viewModel: widget.viewModel,
        isMe: widget.isMe,
      );
    }

    return _FileAttachment(
      attachment: widget.attachment,
      viewModel: widget.viewModel,
      isMe: widget.isMe,
      missing: !_loading && _imageFile == null,
    );
  }
}

class _ImageAttachment extends StatelessWidget {
  final File file;
  final ChatAttachment attachment;
  final GroupChatViewModel viewModel;
  final bool isMe;

  const _ImageAttachment({
    required this.file,
    required this.attachment,
    required this.viewModel,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => viewModel.openAttachment(attachment),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          file,
          width: 220,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => const _MissingFile(),
        ),
      ),
    );
  }
}

class _FileAttachment extends StatelessWidget {
  final ChatAttachment attachment;
  final GroupChatViewModel viewModel;
  final bool isMe;
  final bool missing;

  const _FileAttachment({
    required this.attachment,
    required this.viewModel,
    required this.isMe,
    required this.missing,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isMe ? Colors.white : AppColors.primary;
    final textColor = isMe ? Colors.white : AppColors.text;
    final mutedColor =
        isMe ? Colors.white.withValues(alpha: 0.7) : AppColors.muted;

    return InkWell(
      onTap: missing ? null : () => viewModel.openAttachment(attachment),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.3)
                  : AppColors.primarySoft),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_fileIcon(attachment.mimeType),
                  color: iconColor, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.originalFilename,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${attachment.extension} · ${attachment.fileSizeLabel}',
                    style: TextStyle(fontSize: 11, color: mutedColor),
                  ),
                  if (missing)
                    Text(
                      'Fichier introuvable',
                      style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.orange.shade200 : Colors.orange),
                    ),
                ],
              ),
            ),
            if (!missing)
              IconButton(
                icon: Icon(Icons.share_outlined, size: 18, color: iconColor),
                onPressed: () => viewModel.shareAttachment(attachment),
                tooltip: 'Partager',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  IconData _fileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image_outlined;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('word')) return Icons.article_outlined;
    if (mimeType.contains('sheet') || mimeType.contains('excel')) {
      return Icons.table_chart_outlined;
    }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return Icons.slideshow_outlined;
    }
    if (mimeType == 'text/plain') return Icons.text_snippet_outlined;
    return Icons.attach_file;
  }
}

class _MissingFile extends StatelessWidget {
  const _MissingFile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 120,
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.broken_image_outlined,
            color: AppColors.muted, size: 40),
      ),
    );
  }
}
