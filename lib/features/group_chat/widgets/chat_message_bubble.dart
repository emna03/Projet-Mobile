import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/auth/app_session.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/chat_message.dart';
import '../viewmodels/group_chat_viewmodel.dart';
import 'attachment_card.dart';
import 'poll_card.dart';
import 'reaction_bar.dart';

/// A single message bubble in the chat view.
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final GroupChatViewModel viewModel;
  final bool showSenderInfo;
  final VoidCallback? onReplyTap;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.viewModel,
    this.showSenderInfo = true,
    this.onReplyTap,
  });

  bool get _isMe => message.senderId == AppSession.currentUserId;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return _DeletedBubble(isMe: _isMe);
    }

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: Padding(
        padding: EdgeInsets.only(
          left: _isMe ? 60 : 8,
          right: _isMe ? 8 : 60,
          top: showSenderInfo ? 8 : 2,
          bottom: 2,
        ),
        child: Column(
          crossAxisAlignment:
              _isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!_isMe && showSenderInfo) _SenderRow(message: message),
            Row(
              mainAxisAlignment:
                  _isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!_isMe && showSenderInfo) ...[
                  _buildAvatar(),
                  const SizedBox(width: 6),
                ] else if (!_isMe) ...[
                  const SizedBox(width: 36),
                ],
                Flexible(
                  child: Column(
                    crossAxisAlignment: _isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      _buildBubble(context),
                      if (message.reactions.isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 4, left: 4, right: 4),
                          child: ReactionBar(
                            message: message,
                            viewModel: viewModel,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final color = AppColors.avatarColors[
        message.senderAvatarColorIndex % AppColors.avatarColors.length];
    final initials = _initials(message.senderName);
    return CircleAvatar(
      radius: 14,
      backgroundColor: color,
      child: Text(
        initials,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    final bubbleColor =
        _isMe ? AppColors.primary : Colors.white;
    final textColor = _isMe ? Colors.white : AppColors.text;

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: _isMe ? const Radius.circular(18) : const Radius.circular(4),
          bottomRight:
              _isMe ? const Radius.circular(4) : const Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.replyToMessageId != null)
              _ReplyPreview(
                replyContent: message.replyToContent ?? '',
                replySender: message.replyToSenderName ?? '',
                isMe: _isMe,
                onTap: onReplyTap,
              ),
            if (message.messageType == MessageType.attachment &&
                message.attachment != null)
              AttachmentCard(
                attachment: message.attachment!,
                viewModel: viewModel,
                isMe: _isMe,
              )
            else if (message.messageType == MessageType.poll)
              _PollBubbleContent(message: message, viewModel: viewModel)
            else
              Text(
                message.content,
                style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    color: _isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.muted,
                    fontSize: 11,
                  ),
                ),
                if (message.isEdited) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(modifié)',
                    style: TextStyle(
                      color: _isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
                if (viewModel.pinnedMessages
                    .any((p) => p.id == message.id)) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.push_pin,
                    size: 11,
                    color: _isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.muted,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final isOwner = viewModel.isOwner;
    final isMyMsg = _isMe;
    final isPinned =
        viewModel.pinnedMessages.any((p) => p.id == message.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _ReactionSelector(messageId: message.id, viewModel: viewModel),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Répondre'),
              onTap: () {
                Navigator.pop(sheetCtx);
                viewModel.setReplyTo(message);
              },
            ),
            if (message.messageType == MessageType.text)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copier'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Texte copié'),
                        duration: Duration(seconds: 1)),
                  );
                },
              ),
            if (isMyMsg && message.messageType == MessageType.text)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  viewModel.startEdit(message);
                },
              ),
            if (isMyMsg)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Supprimer',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await viewModel.deleteMessage(message.id);
                },
              ),
            if (isOwner)
              ListTile(
                leading: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: AppColors.primary,
                ),
                title:
                    Text(isPinned ? 'Désépingler' : 'Épingler'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  if (isPinned) {
                    await viewModel.unpinMessage(message.id);
                  } else {
                    await viewModel.pinMessage(message.id);
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _DeletedBubble extends StatelessWidget {
  final bool isMe;
  const _DeletedBubble({required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 60 : 8,
        right: isMe ? 8 : 60,
        top: 2,
        bottom: 2,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Ce message a été supprimé.',
            style: TextStyle(
                color: AppColors.muted,
                fontStyle: FontStyle.italic,
                fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _SenderRow extends StatelessWidget {
  final ChatMessage message;
  const _SenderRow({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 42, bottom: 2),
      child: Text(
        message.senderName,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  final String replyContent;
  final String replySender;
  final bool isMe;
  final VoidCallback? onTap;

  const _ReplyPreview({
    required this.replyContent,
    required this.replySender,
    required this.isMe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.2)
              : AppColors.primarySoft,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isMe ? Colors.white : AppColors.primary,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              replySender,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isMe ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              replyContent,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionSelector extends StatelessWidget {
  final String messageId;
  final GroupChatViewModel viewModel;

  static const _emojis = ['👍', '❤️', '😂', '🎉', '🔥', '👏'];

  const _ReactionSelector({
    required this.messageId,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _emojis
            .map(
              (e) => GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  await viewModel.toggleReaction(messageId, e);
                },
                child: Text(e, style: const TextStyle(fontSize: 28)),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PollBubbleContent extends StatelessWidget {
  final ChatMessage message;
  final GroupChatViewModel viewModel;

  const _PollBubbleContent({required this.message, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final poll = viewModel.pollCache[message.id];
    if (poll == null) {
      return const Text('Sondage en cours de chargement…',
          style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.muted));
    }
    return PollCard(poll: poll, viewModel: viewModel, messageId: message.id);
  }
}
