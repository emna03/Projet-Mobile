import 'package:flutter/material.dart';

import '../../../../core/auth/app_session.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/group_poll.dart';
import '../viewmodels/group_chat_viewmodel.dart';

/// Inline poll card rendered inside a message bubble.
class PollCard extends StatelessWidget {
  final GroupPoll poll;
  final GroupChatViewModel viewModel;
  final String messageId;

  const PollCard({
    super.key,
    required this.poll,
    required this.viewModel,
    required this.messageId,
  });

  @override
  Widget build(BuildContext context) {
    final isOwnerOrCreator = AppSession.currentUserId == poll.createdBy ||
        viewModel.isOwner;

    return Container(
      width: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text(
                'Sondage',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
              ),
              const Spacer(),
              if (poll.isClosed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Fermé',
                      style:
                          TextStyle(fontSize: 10, color: AppColors.muted)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            poll.question,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.text),
          ),
          const SizedBox(height: 10),
          ...poll.options.map((opt) => _PollOptionRow(
                option: opt,
                totalVotes: poll.totalVotes,
                isClosed: poll.isClosed,
                messageId: messageId,
                viewModel: viewModel,
                pollId: poll.id,
              )),
          const SizedBox(height: 6),
          Text(
            '${poll.totalVotes} vote${poll.totalVotes != 1 ? 's' : ''}',
            style:
                const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          if (!poll.isClosed && isOwnerOrCreator) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => viewModel.closePoll(poll.id, messageId),
              child: const Text(
                'Fermer le sondage',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PollOptionRow extends StatelessWidget {
  final PollOption option;
  final int totalVotes;
  final bool isClosed;
  final String messageId;
  final String pollId;
  final GroupChatViewModel viewModel;

  const _PollOptionRow({
    required this.option,
    required this.totalVotes,
    required this.isClosed,
    required this.messageId,
    required this.pollId,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalVotes == 0
        ? 0.0
        : option.voteCount / totalVotes;
    final isSelected = option.isSelectedByCurrentUser;

    return GestureDetector(
      onTap: isClosed
          ? null
          : () => viewModel.vote(
                pollId: pollId,
                optionId: option.id,
                messageId: messageId,
              ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Stack(
          children: [
            // Progress bar background
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 36,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.primarySoft,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: pct,
                  child: Container(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : AppColors.primarySoft,
                  ),
                ),
              ),
            ),
            // Text overlay
            SizedBox(
              height: 36,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.optionText,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.text,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(pct * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.muted),
                    ),
                    if (isSelected)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.check_circle,
                            size: 14, color: AppColors.primary),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
