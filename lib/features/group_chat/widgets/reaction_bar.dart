import 'package:flutter/material.dart';

import '../../../../core/auth/app_session.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/chat_message.dart';
import '../viewmodels/group_chat_viewmodel.dart';

/// Displays grouped emoji reactions below a message bubble.
class ReactionBar extends StatelessWidget {
  final ChatMessage message;
  final GroupChatViewModel viewModel;

  const ReactionBar({
    super.key,
    required this.message,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    // Group reactions by emoji
    final grouped = <String, List<MessageReaction>>{};
    for (final r in message.reactions) {
      grouped.putIfAbsent(r.emoji, () => []).add(r);
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: grouped.entries.map((entry) {
        final emoji = entry.key;
        final reactors = entry.value;
        final count = reactors.length;
        final iMine =
            reactors.any((r) => r.userId == AppSession.currentUserId);

        return GestureDetector(
          onTap: () => viewModel.toggleReaction(message.id, emoji),
          onLongPress: () => _showReactors(context, emoji, reactors),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: iMine ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: iMine ? AppColors.primary : AppColors.primarySoft,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: iMine ? Colors.white : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showReactors(
      BuildContext context, String emoji, List<MessageReaction> reactors) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$emoji ${reactors.length} réaction${reactors.length > 1 ? 's' : ''}',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text),
            ),
            const SizedBox(height: 12),
            ...reactors.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primarySoft,
                        child: Text(
                          r.userName.isNotEmpty ? r.userName[0] : '?',
                          style: const TextStyle(
                              color: AppColors.primary, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(r.userName,
                          style: const TextStyle(color: AppColors.text)),
                      if (r.userId == AppSession.currentUserId) ...[
                        const SizedBox(width: 6),
                        const Text('(vous)',
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                      ],
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
