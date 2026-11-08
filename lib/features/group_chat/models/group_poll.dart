/// Status of a group poll.
enum PollStatus { open, closed }

/// A poll posted inside a group chat.
class GroupPoll {
  final String id;
  final String groupId;
  final String messageId;
  final String question;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? closedAt;
  final List<PollOption> options;

  PollStatus get status => closedAt != null ? PollStatus.closed : PollStatus.open;
  bool get isClosed => closedAt != null;

  int get totalVotes => options.fold(0, (sum, o) => sum + o.voteCount);

  const GroupPoll({
    required this.id,
    required this.groupId,
    required this.messageId,
    required this.question,
    required this.createdBy,
    required this.createdAt,
    this.closedAt,
    required this.options,
  });

  GroupPoll copyWith({
    DateTime? closedAt,
    List<PollOption>? options,
  }) {
    return GroupPoll(
      id: id,
      groupId: groupId,
      messageId: messageId,
      question: question,
      createdBy: createdBy,
      createdAt: createdAt,
      closedAt: closedAt ?? this.closedAt,
      options: options ?? this.options,
    );
  }
}

/// A single answer option in a poll.
class PollOption {
  final String id;
  final String pollId;
  final String optionText;
  final int displayOrder;
  final int voteCount;
  final bool isSelectedByCurrentUser;

  const PollOption({
    required this.id,
    required this.pollId,
    required this.optionText,
    required this.displayOrder,
    this.voteCount = 0,
    this.isSelectedByCurrentUser = false,
  });

  PollOption copyWith({
    int? voteCount,
    bool? isSelectedByCurrentUser,
  }) {
    return PollOption(
      id: id,
      pollId: pollId,
      optionText: optionText,
      displayOrder: displayOrder,
      voteCount: voteCount ?? this.voteCount,
      isSelectedByCurrentUser:
          isSelectedByCurrentUser ?? this.isSelectedByCurrentUser,
    );
  }
}
