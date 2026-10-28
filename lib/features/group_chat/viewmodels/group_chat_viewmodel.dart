import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/auth/app_session.dart';
import '../models/chat_message.dart';
import '../models/group_poll.dart';
import '../repositories/group_chat_repository.dart';
import '../services/attachment_storage_service.dart';

/// ViewModel for the group chat screen.
///
/// Manages loading state, message list, reactions, polls, pinned messages,
/// and attachment operations. Uses [ChangeNotifier] + [ListenableBuilder].
class GroupChatViewModel extends ChangeNotifier {
  GroupChatViewModel({
    required this.groupId,
    required this.groupName,
    required this.groupOwnerId,
    required this.memberCount,
    GroupChatRepository? repository,
    AttachmentStorageService? storageService,
  })  : _repo = repository ?? GroupChatRepository(),
        _storage = storageService ?? AttachmentStorageService() {
    loadMessages();
    loadPinnedMessages();
  }

  final String groupId;
  final String groupName;
  final String groupOwnerId;
  final int memberCount;
  final GroupChatRepository _repo;
  final AttachmentStorageService _storage;

  // ─── State ────────────────────────────────────────────────────────────────

  List<ChatMessage> _messages = [];
  List<ChatMessage> _pinnedMessages = [];
  final Map<String, GroupPoll> _pollCache = {};

  bool _isLoading = false;
  bool _isSending = false;
  bool _hasMore = true;
  String? _errorMessage;

  // Compose state
  ChatMessage? _replyingTo;
  bool _isEditing = false;
  ChatMessage? _editingMessage;

  // Search
  bool _isSearching = false;
  List<ChatMessage> _searchResults = [];
  String _searchQuery = '';

  // ─── Getters ─────────────────────────────────────────────────────────────

  List<ChatMessage> get messages => _messages;
  List<ChatMessage> get pinnedMessages => _pinnedMessages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  ChatMessage? get replyingTo => _replyingTo;
  bool get isEditing => _isEditing;
  ChatMessage? get editingMessage => _editingMessage;
  bool get isSearching => _isSearching;
  List<ChatMessage> get searchResults => _searchResults;
  String get searchQuery => _searchQuery;
  String get currentUserId => AppSession.currentUserId;
  bool get isOwner => currentUserId == groupOwnerId;
  Map<String, GroupPoll> get pollCache => _pollCache;

  // ─── Loading ─────────────────────────────────────────────────────────────

  Future<void> loadMessages() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final msgs = await _repo.getMessages(
        groupId,
        userId: currentUserId,
        limit: 40,
      );
      _messages = msgs;
      _hasMore = msgs.length >= 40;
      await _loadPollsForMessages(msgs);
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des messages.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreMessages() async {
    if (!_hasMore || _isLoading || _messages.isEmpty) return;

    try {
      final older = await _repo.getMessages(
        groupId,
        userId: currentUserId,
        limit: 40,
        beforeId: _messages.first.id,
      );
      _messages = [...older, ..._messages];
      _hasMore = older.length >= 40;
      await _loadPollsForMessages(older);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadPinnedMessages() async {
    try {
      _pinnedMessages = await _repo.getPinnedMessages(groupId, currentUserId);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadPollsForMessages(List<ChatMessage> msgs) async {
    for (final msg in msgs) {
      if (msg.messageType == MessageType.poll) {
        try {
          final poll =
              await _repo.getPollForMessage(msg.id, currentUserId);
          if (poll != null) _pollCache[msg.id] = poll;
        } catch (_) {}
      }
    }
  }

  // ─── Sending ──────────────────────────────────────────────────────────────

  Future<bool> sendTextMessage(String content) async {
    final text = content.trim();
    if (text.isEmpty) return false;
    if (_isSending) return false;

    _isSending = true;
    notifyListeners();

    try {
      if (_isEditing && _editingMessage != null) {
        // Edit mode
        final ok = await _repo.editMessage(
          messageId: _editingMessage!.id,
          userId: currentUserId,
          newContent: text,
        );
        if (ok) {
          _refreshMessage(_editingMessage!.id);
        }
        clearCompose();
      } else {
        // New message
        final msg = await _repo.sendMessage(
          groupId: groupId,
          senderId: currentUserId,
          content: text,
          replyToMessageId: _replyingTo?.id,
        );
        if (msg != null) {
          _messages.add(msg);
        }
        clearCompose();
      }
      return true;
    } catch (_) {
      _errorMessage = "Erreur lors de l'envoi du message.";
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<bool> pickAndSendFile() async {
    if (_isSending) return false;

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: AttachmentStorageService.allowedExtensions,
      );

      if (result == null || result.files.isEmpty) return false;
      final pickedFile = result.files.first;
      if (pickedFile.path == null) return false;

      _isSending = true;
      notifyListeners();

      final stored = await _storage.storeFile(pickedFile.path!, groupId);

      final msg = await _repo.sendAttachmentMessage(
        groupId: groupId,
        senderId: currentUserId,
        originalFilename: pickedFile.name,
        localPath: stored.relativePath,
        mimeType: stored.mimeType,
        fileSize: stored.fileSize,
        replyToMessageId: _replyingTo?.id,
      );

      if (msg != null) {
        _messages.add(msg);
        clearCompose();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage =
          e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<bool> sendPoll({
    required String question,
    required List<String> options,
  }) async {
    if (_isSending) return false;

    _isSending = true;
    notifyListeners();

    try {
      final msg = await _repo.sendPollMessage(
        groupId: groupId,
        senderId: currentUserId,
        question: question,
        options: options,
      );

      if (msg != null) {
        final poll =
            await _repo.getPollForMessage(msg.id, currentUserId);
        if (poll != null) _pollCache[msg.id] = poll;
        _messages.add(msg);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      _errorMessage = 'Erreur lors de la création du sondage.';
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // ─── Editing / deleting ────────────────────────────────────────────────────

  void startEdit(ChatMessage message) {
    _isEditing = true;
    _editingMessage = message;
    notifyListeners();
  }

  Future<bool> deleteMessage(String messageId) async {
    final ok = await _repo.deleteMessage(
      messageId: messageId,
      userId: currentUserId,
    );
    if (ok) await _refreshMessage(messageId);
    return ok;
  }

  // ─── Reactions ────────────────────────────────────────────────────────────

  Future<void> toggleReaction(String messageId, String emoji) async {
    await _repo.toggleReaction(
      messageId: messageId,
      userId: currentUserId,
      emoji: emoji,
    );
    await _refreshMessage(messageId);
  }

  // ─── Pinning ──────────────────────────────────────────────────────────────

  Future<bool> pinMessage(String messageId) async {
    final ok = await _repo.pinMessage(
      groupId: groupId,
      messageId: messageId,
      pinnedBy: currentUserId,
      ownerId: groupOwnerId,
    );
    if (ok) await loadPinnedMessages();
    return ok;
  }

  Future<bool> unpinMessage(String messageId) async {
    final ok = await _repo.unpinMessage(
      groupId: groupId,
      messageId: messageId,
      requestedBy: currentUserId,
      ownerId: groupOwnerId,
    );
    if (ok) await loadPinnedMessages();
    return ok;
  }

  // ─── Polls ────────────────────────────────────────────────────────────────

  Future<bool> vote({required String pollId, required String optionId, required String messageId}) async {
    final ok = await _repo.vote(
      pollId: pollId,
      optionId: optionId,
      userId: currentUserId,
    );
    if (ok) {
      final poll = await _repo.getPollForMessage(messageId, currentUserId);
      if (poll != null) {
        _pollCache[messageId] = poll;
        notifyListeners();
      }
    }
    return ok;
  }

  Future<bool> closePoll(String pollId, String messageId) async {
    bool ok;
    if (currentUserId == groupOwnerId) {
      ok = await _repo.closePollForce(pollId);
    } else {
      ok = await _repo.closePoll(
          pollId: pollId, requestedBy: currentUserId);
    }
    if (ok) {
      final poll = await _repo.getPollForMessage(messageId, currentUserId);
      if (poll != null) {
        _pollCache[messageId] = poll;
        notifyListeners();
      }
    }
    return ok;
  }

  // ─── File actions ─────────────────────────────────────────────────────────

  Future<void> openAttachment(ChatAttachment attachment) async {
    try {
      final file = await _storage.resolveFile(attachment.localPath);
      if (!file.existsSync()) {
        _errorMessage = 'Fichier introuvable sur cet appareil.';
        notifyListeners();
        return;
      }
      await OpenFilex.open(file.path);
    } catch (e) {
      _errorMessage = "Impossible d'ouvrir le fichier.";
      notifyListeners();
    }
  }

  Future<void> shareAttachment(ChatAttachment attachment) async {
    try {
      final file = await _storage.resolveFile(attachment.localPath);
      if (!file.existsSync()) {
        _errorMessage = 'Fichier introuvable.';
        notifyListeners();
        return;
      }
      await Share.shareXFiles([XFile(file.path)],
          text: attachment.originalFilename);
    } catch (e) {
      _errorMessage = 'Impossible de partager le fichier.';
      notifyListeners();
    }
  }

  // ─── Media gallery helper ─────────────────────────────────────────────────

  /// Returns the absolute path for [relativePath] if the file exists, else null.
  Future<String?> resolveAttachmentPath(String relativePath) async {
    try {
      final file = await _storage.resolveFile(relativePath);
      return file.existsSync() ? file.path : null;
    } catch (_) {
      return null;
    }
  }

  // ─── Search ───────────────────────────────────────────────────────────────


  void toggleSearch() {
    _isSearching = !_isSearching;
    if (!_isSearching) {
      _searchResults = [];
      _searchQuery = '';
    }
    notifyListeners();
  }

  Future<void> search(String query) async {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    try {
      _searchResults = await _repo.searchMessages(
        groupId: groupId,
        userId: currentUserId,
        query: query,
      );
    } catch (_) {
      _searchResults = [];
    }
    notifyListeners();
  }

  // ─── Compose state management ─────────────────────────────────────────────

  void setReplyTo(ChatMessage? message) {
    _replyingTo = message;
    _isEditing = false;
    _editingMessage = null;
    notifyListeners();
  }

  void clearCompose() {
    _replyingTo = null;
    _isEditing = false;
    _editingMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ─── Shared files ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSharedFiles() async {
    return _repo.getSharedFiles(groupId);
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  Future<void> _refreshMessage(String messageId) async {
    try {
      // Re-load the single message by fetching messages and finding it
      final fresh = await _repo.getMessages(
        groupId,
        userId: currentUserId,
        limit: 200,
      );
      final idx = _messages.indexWhere((m) => m.id == messageId);
      final freshMsg = fresh.firstWhere(
        (m) => m.id == messageId,
        orElse: () => _messages[idx < 0 ? 0 : idx],
      );
      if (idx >= 0) {
        _messages[idx] = freshMsg;
      }
    } catch (_) {}
    notifyListeners();
  }
}
