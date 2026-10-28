import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_migrations.dart';
import '../models/chat_message.dart';
import '../models/group_poll.dart';

/// Repository for all group-chat related data access.
///
/// Handles messages, attachments, reactions, pinned messages, and polls.
/// All SQL is parameterised; no business logic lives here.
class GroupChatRepository {
  GroupChatRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  Future<Database> get _conn => _db.database;

  // Table aliases
  static const _tm = DatabaseMigrations.tGroupMessages;
  static const _ta = DatabaseMigrations.tGroupAttachments;
  static const _tr = DatabaseMigrations.tMessageReactions;
  static const _tp = DatabaseMigrations.tPinnedMessages;
  static const _tpoll = DatabaseMigrations.tGroupPolls;
  static const _topt = DatabaseMigrations.tPollOptions;
  static const _tvote = DatabaseMigrations.tPollVotes;
  static const _tu = DatabaseMigrations.tUsers;
  static const _tg = DatabaseMigrations.tGroupMembers;

  // ─── Access control ─────────────────────────────────────────────────────────

  /// Returns true if [userId] is a member or owner of [groupId].
  Future<bool> canAccess(String groupId, String userId) async {
    final db = await _conn;
    final rows = await db.query(
      _tg,
      where: 'group_id = ? AND user_id = ?',
      whereArgs: [groupId, userId],
    );
    return rows.isNotEmpty;
  }

  // ─── Message CRUD ────────────────────────────────────────────────────────────

  /// Loads a page of messages for [groupId].
  ///
  /// [limit] messages before [beforeId] (exclusive). Returns newest-first
  /// so callers can reverse for display.
  Future<List<ChatMessage>> getMessages(
    String groupId, {
    String userId = '',
    int limit = 40,
    String? beforeId,
  }) async {
    final db = await _conn;

    String whereClause = 'group_id = ?';
    List<Object> whereArgs = [groupId];

    if (beforeId != null) {
      final anchorRows = await db.query(_tm,
          columns: ['created_at'],
          where: 'id = ?',
          whereArgs: [beforeId]);
      if (anchorRows.isNotEmpty) {
        whereClause += ' AND created_at < ?';
        whereArgs.add(anchorRows.first['created_at'] as String);
      }
    }

    final rows = await db.query(
      _tm,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    final messages = <ChatMessage>[];
    for (final row in rows) {
      final msg = await _buildMessage(db, row, userId);
      messages.add(msg);
    }
    // Return chronological order (oldest first) for the list view
    return messages.reversed.toList();
  }

  /// Sends a text message. Returns the created [ChatMessage] or null on error.
  Future<ChatMessage?> sendMessage({
    required String groupId,
    required String senderId,
    required String content,
    String? replyToMessageId,
  }) async {
    final db = await _conn;

    // Verify access
    if (!await canAccess(groupId, senderId)) return null;

    final id = 'msg_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();

    await db.insert(_tm, {
      'id': id,
      'group_id': groupId,
      'sender_id': senderId,
      'message_type': 'text',
      'content': content,
      'reply_to_message_id': replyToMessageId,
      'created_at': now,
    });

    return _getMessageById(db, id, senderId);
  }

  /// Sends an attachment message. Returns the created [ChatMessage] or null.
  Future<ChatMessage?> sendAttachmentMessage({
    required String groupId,
    required String senderId,
    required String originalFilename,
    required String localPath,
    required String mimeType,
    required int fileSize,
    String? replyToMessageId,
  }) async {
    final db = await _conn;

    if (!await canAccess(groupId, senderId)) return null;

    final msgId = 'msg_${DateTime.now().microsecondsSinceEpoch}';
    final attachId = 'att_${DateTime.now().microsecondsSinceEpoch}_a';
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert(_tm, {
        'id': msgId,
        'group_id': groupId,
        'sender_id': senderId,
        'message_type': 'attachment',
        'content': originalFilename,
        'reply_to_message_id': replyToMessageId,
        'created_at': now,
      });

      await txn.insert(_ta, {
        'id': attachId,
        'message_id': msgId,
        'original_filename': originalFilename,
        'local_path': localPath,
        'mime_type': mimeType,
        'file_size': fileSize,
        'created_at': now,
      });
    });

    return _getMessageById(db, msgId, senderId);
  }

  /// Sends a poll message. Returns the created poll's message ID or null.
  Future<ChatMessage?> sendPollMessage({
    required String groupId,
    required String senderId,
    required String question,
    required List<String> options,
  }) async {
    final db = await _conn;

    if (!await canAccess(groupId, senderId)) return null;
    if (options.length < 2 || options.length > 8) return null;

    final msgId = 'msg_${DateTime.now().microsecondsSinceEpoch}';
    final pollId = 'poll_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert(_tm, {
        'id': msgId,
        'group_id': groupId,
        'sender_id': senderId,
        'message_type': 'poll',
        'content': question,
        'created_at': now,
      });

      await txn.insert(_tpoll, {
        'id': pollId,
        'group_id': groupId,
        'message_id': msgId,
        'question': question,
        'created_by': senderId,
        'created_at': now,
      });

      for (int i = 0; i < options.length; i++) {
        await txn.insert(_topt, {
          'id': 'opt_${DateTime.now().microsecondsSinceEpoch}_$i',
          'poll_id': pollId,
          'option_text': options[i],
          'display_order': i,
        });
      }
    });

    return _getMessageById(db, msgId, senderId);
  }

  /// Edits the content of a message owned by [userId].
  Future<bool> editMessage({
    required String messageId,
    required String userId,
    required String newContent,
  }) async {
    final db = await _conn;
    final updated = await db.update(
      _tm,
      {
        'content': newContent,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND sender_id = ? AND deleted_at IS NULL',
      whereArgs: [messageId, userId],
    );
    return updated > 0;
  }

  /// Soft-deletes a message owned by [userId].
  Future<bool> deleteMessage({
    required String messageId,
    required String userId,
  }) async {
    final db = await _conn;
    final updated = await db.update(
      _tm,
      {
        'content': 'Ce message a été supprimé.',
        'deleted_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND sender_id = ? AND deleted_at IS NULL',
      whereArgs: [messageId, userId],
    );
    return updated > 0;
  }

  // ─── Reactions ────────────────────────────────────────────────────────────

  /// Toggles an emoji reaction. Adds if missing, removes if existing.
  Future<void> toggleReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final db = await _conn;

    final existing = await db.query(
      _tr,
      where: 'message_id = ? AND user_id = ? AND emoji = ?',
      whereArgs: [messageId, userId, emoji],
    );

    if (existing.isEmpty) {
      await db.insert(
        _tr,
        {
          'message_id': messageId,
          'user_id': userId,
          'emoji': emoji,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      await db.delete(
        _tr,
        where: 'message_id = ? AND user_id = ? AND emoji = ?',
        whereArgs: [messageId, userId, emoji],
      );
    }
  }

  // ─── Pinned messages ─────────────────────────────────────────────────────

  /// Returns all pinned messages for [groupId].
  Future<List<ChatMessage>> getPinnedMessages(
      String groupId, String userId) async {
    final db = await _conn;
    final rows = await db.rawQuery('''
      SELECT m.*
      FROM $_tm m
      INNER JOIN $_tp p ON p.message_id = m.id
      WHERE p.group_id = ?
      ORDER BY p.pinned_at DESC
    ''', [groupId]);

    final messages = <ChatMessage>[];
    for (final row in rows) {
      messages.add(await _buildMessage(db, row, userId));
    }
    return messages;
  }

  /// Pins a message — only the group owner may do this.
  Future<bool> pinMessage({
    required String groupId,
    required String messageId,
    required String pinnedBy,
    required String ownerId,
  }) async {
    if (pinnedBy != ownerId) return false;
    final db = await _conn;
    try {
      await db.insert(
        _tp,
        {
          'group_id': groupId,
          'message_id': messageId,
          'pinned_by': pinnedBy,
          'pinned_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Unpins a message — only the group owner may do this.
  Future<bool> unpinMessage({
    required String groupId,
    required String messageId,
    required String requestedBy,
    required String ownerId,
  }) async {
    if (requestedBy != ownerId) return false;
    final db = await _conn;
    final deleted = await db.delete(
      _tp,
      where: 'group_id = ? AND message_id = ?',
      whereArgs: [groupId, messageId],
    );
    return deleted > 0;
  }

  // ─── Polls ────────────────────────────────────────────────────────────────

  /// Returns the poll associated with a given message id.
  Future<GroupPoll?> getPollForMessage(
      String messageId, String userId) async {
    final db = await _conn;
    final rows = await db.query(
      _tpoll,
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
    if (rows.isEmpty) return null;
    return _buildPoll(db, rows.first, userId);
  }

  /// Vote or change vote for a poll (single-choice).
  Future<bool> vote({
    required String pollId,
    required String optionId,
    required String userId,
  }) async {
    final db = await _conn;

    return db.transaction<bool>((txn) async {
      // Check poll is still open
      final pollRows = await txn.query(_tpoll,
          columns: ['closed_at'],
          where: 'id = ?',
          whereArgs: [pollId]);
      if (pollRows.isEmpty) return false;
      if (pollRows.first['closed_at'] != null) return false;

      // Upsert vote (replace existing choice)
      await txn.delete(_tvote,
          where: 'poll_id = ? AND user_id = ?', whereArgs: [pollId, userId]);

      await txn.insert(_tvote, {
        'poll_id': pollId,
        'option_id': optionId,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    });
  }

  /// Closes a poll — only creator or group owner may do this.
  Future<bool> closePoll({
    required String pollId,
    required String requestedBy,
  }) async {
    final db = await _conn;

    final pollRows = await db.query(_tpoll,
        columns: ['created_by'], where: 'id = ?', whereArgs: [pollId]);
    if (pollRows.isEmpty) return false;

    final createdBy = pollRows.first['created_by'] as String;
    if (createdBy != requestedBy) {
      // Also allow group owner — check group owner vs requestedBy
      // We'll rely on ViewModel to check owner; here we check creator only
      // for simplicity. ViewModel passes the correct requestedBy.
      return false;
    }

    final updated = await db.update(
      _tpoll,
      {'closed_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND closed_at IS NULL',
      whereArgs: [pollId],
    );
    return updated > 0;
  }

  /// Forces poll closure (for group owner override path).
  Future<bool> closePollForce(String pollId) async {
    final db = await _conn;
    final updated = await db.update(
      _tpoll,
      {'closed_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND closed_at IS NULL',
      whereArgs: [pollId],
    );
    return updated > 0;
  }

  // ─── Search ───────────────────────────────────────────────────────────────

  Future<List<ChatMessage>> searchMessages({
    required String groupId,
    required String userId,
    required String query,
  }) async {
    final db = await _conn;
    if (query.trim().isEmpty) return [];

    final rows = await db.query(
      _tm,
      where:
          "group_id = ? AND deleted_at IS NULL AND content LIKE ? AND message_type = 'text'",
      whereArgs: [groupId, '%${query.trim()}%'],
      orderBy: 'created_at DESC',
      limit: 50,
    );

    final messages = <ChatMessage>[];
    for (final row in rows) {
      messages.add(await _buildMessage(db, row, userId));
    }
    return messages;
  }

  // ─── Shared files ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSharedFiles(String groupId) async {
    final db = await _conn;
    return db.rawQuery('''
      SELECT a.*, m.created_at as sent_at, m.sender_id,
             u.name as sender_name, u.avatar_color as sender_color
      FROM $_ta a
      INNER JOIN $_tm m ON m.id = a.message_id
      INNER JOIN $_tu u ON u.id = m.sender_id
      WHERE m.group_id = ? AND m.deleted_at IS NULL
      ORDER BY m.created_at DESC
    ''', [groupId]);
  }

  // ─── Private builders ────────────────────────────────────────────────────

  Future<ChatMessage?> _getMessageById(
      Database db, String id, String userId) async {
    final rows = await db.query(_tm, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _buildMessage(db, rows.first, userId);
  }

  Future<ChatMessage> _buildMessage(
      Database db, Map<String, dynamic> row, String userId) async {
    final msgId = row['id'] as String;
    final senderId = row['sender_id'] as String;

    // Load sender info
    final userRows =
        await db.query(_tu, where: 'id = ?', whereArgs: [senderId]);
    final senderName = userRows.isEmpty
        ? 'Utilisateur inconnu'
        : userRows.first['name'] as String;
    final senderColor =
        userRows.isEmpty ? 0 : userRows.first['avatar_color'] as int? ?? 0;

    // Load reactions
    final reactionRows = await db.rawQuery('''
      SELECT r.*, u.name as user_name
      FROM $_tr r
      LEFT JOIN $_tu u ON u.id = r.user_id
      WHERE r.message_id = ?
    ''', [msgId]);

    final reactions = reactionRows
        .map((r) => MessageReaction(
              messageId: msgId,
              userId: r['user_id'] as String,
              userName: r['user_name'] as String? ?? '',
              emoji: r['emoji'] as String,
              createdAt: DateTime.parse(r['created_at'] as String),
            ))
        .toList();

    // Load attachment if message_type == attachment
    ChatAttachment? attachment;
    final msgType = row['message_type'] as String? ?? 'text';
    if (msgType == 'attachment') {
      final attRows = await db
          .query(_ta, where: 'message_id = ?', whereArgs: [msgId]);
      if (attRows.isNotEmpty) {
        final a = attRows.first;
        attachment = ChatAttachment(
          id: a['id'] as String,
          messageId: msgId,
          originalFilename: a['original_filename'] as String,
          localPath: a['local_path'] as String,
          mimeType: a['mime_type'] as String? ?? 'application/octet-stream',
          fileSize: a['file_size'] as int? ?? 0,
          createdAt: DateTime.parse(a['created_at'] as String),
        );
      }
    }

    // Load reply preview
    String? replyToContent;
    String? replyToSenderName;
    final replyId = row['reply_to_message_id'] as String?;
    if (replyId != null) {
      final replyRows =
          await db.query(_tm, where: 'id = ?', whereArgs: [replyId]);
      if (replyRows.isNotEmpty) {
        final rRow = replyRows.first;
        replyToContent = rRow['deleted_at'] != null
            ? 'Message supprimé'
            : rRow['content'] as String? ?? '';
        final rUserRows = await db.query(_tu,
            where: 'id = ?', whereArgs: [rRow['sender_id']]);
        replyToSenderName = rUserRows.isEmpty
            ? ''
            : rUserRows.first['name'] as String;
      }
    }

    return ChatMessage(
      id: msgId,
      groupId: row['group_id'] as String,
      senderId: senderId,
      senderName: senderName,
      senderAvatarColorIndex: senderColor,
      messageType: _parseMessageType(msgType),
      content: row['content'] as String? ?? '',
      replyToMessageId: replyId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'] as String)
          : null,
      deletedAt: row['deleted_at'] != null
          ? DateTime.tryParse(row['deleted_at'] as String)
          : null,
      reactions: reactions,
      attachment: attachment,
    );
  }

  Future<GroupPoll> _buildPoll(
      Database db, Map<String, dynamic> pollRow, String userId) async {
    final pollId = pollRow['id'] as String;

    final optRows = await db.query(
      _topt,
      where: 'poll_id = ?',
      whereArgs: [pollId],
      orderBy: 'display_order ASC',
    );

    final voteRows = await db.rawQuery('''
      SELECT option_id, COUNT(*) as cnt
      FROM $_tvote
      WHERE poll_id = ?
      GROUP BY option_id
    ''', [pollId]);

    final voteCounts = <String, int>{};
    for (final v in voteRows) {
      voteCounts[v['option_id'] as String] = v['cnt'] as int? ?? 0;
    }

    // Current user's vote
    final myVoteRows = await db.query(
      _tvote,
      columns: ['option_id'],
      where: 'poll_id = ? AND user_id = ?',
      whereArgs: [pollId, userId],
    );
    final myOptionId =
        myVoteRows.isEmpty ? null : myVoteRows.first['option_id'] as String?;

    final options = optRows.map((o) {
      final oid = o['id'] as String;
      return PollOption(
        id: oid,
        pollId: pollId,
        optionText: o['option_text'] as String,
        displayOrder: o['display_order'] as int? ?? 0,
        voteCount: voteCounts[oid] ?? 0,
        isSelectedByCurrentUser: oid == myOptionId,
      );
    }).toList();

    return GroupPoll(
      id: pollId,
      groupId: pollRow['group_id'] as String,
      messageId: pollRow['message_id'] as String,
      question: pollRow['question'] as String,
      createdBy: pollRow['created_by'] as String,
      createdAt: DateTime.parse(pollRow['created_at'] as String),
      closedAt: pollRow['closed_at'] != null
          ? DateTime.tryParse(pollRow['closed_at'] as String)
          : null,
      options: options,
    );
  }

  MessageType _parseMessageType(String type) {
    switch (type) {
      case 'attachment':
        return MessageType.attachment;
      case 'poll':
        return MessageType.poll;
      default:
        return MessageType.text;
    }
  }
}
