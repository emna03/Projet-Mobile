import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/session_user.dart';
import '../models/chat_message.dart';
import '../models/group_poll.dart';
import '../repositories/group_chat_repository.dart';
import '../services/attachment_storage_service.dart';

/// ViewModel for the group chat screen.
///
/// Manages loading state, message list, reactions, polls, pinned messages,
/// and attachment operations. Uses [ChangeNotifier] + [ListenableBuilder].
///
/// Intégration : l'utilisateur courant est l'utilisateur Firebase connecté
/// ([SessionUser.uid]) et les messages, sondages et épingles sont reçus en
/// temps réel depuis Firestore.
class GroupChatViewModel extends ChangeNotifier {
  GroupChatViewModel({
    required this.groupId,
    required this.groupName,
    required this.groupOwnerId,
    required this.memberCount,
    GroupChatRepository? repository,
    AttachmentStorageService? storageService,
    String Function()? currentUserIdProvider,
  })  : _repo = repository ?? GroupChatRepository(),
        _storage = storageService ?? AttachmentStorageService(),
        _currentUserId = currentUserIdProvider ?? (() => SessionUser.uid) {
    loadMessages();
    loadPinnedMessages();
    _listenRealtime();
  }

  static const _pageSize = 40;

  final String groupId;
  final String groupName;
  final String groupOwnerId;
  final int memberCount;
  final GroupChatRepository _repo;
  final AttachmentStorageService _storage;
  final String Function() _currentUserId;

  final List<StreamSubscription<Object?>> _subs = [];
  bool _disposed = false;

  // ─── State ────────────────────────────────────────────────────────────────

  /// Messages plus anciens chargés par pagination.
  List<ChatMessage> _older = [];

  /// Fenêtre temps réel des derniers messages.
  List<ChatMessage> _live = [];
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
  String get currentUserId => _currentUserId();
  bool get isOwner => currentUserId.isNotEmpty && currentUserId == groupOwnerId;
  Map<String, GroupPoll> get pollCache => _pollCache;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  // ─── Temps réel ──────────────────────────────────────────────────────────

  void _listenRealtime() {
    void onError(Object e) {
      debugPrint('GroupChatViewModel stream: $e');
      _errorMessage = 'Accès au chat refusé ou réseau indisponible.';
      _notify();
    }

    _subs
      ..add(_repo.watchMessages(groupId, limit: _pageSize).listen(_onLive, onError: onError))
      ..add(_repo.watchPolls(groupId, currentUserId).listen((polls) {
        _pollCache
          ..clear()
          ..addAll(polls);
        _notify();
      }, onError: onError))
      ..add(_repo.watchPinned(groupId).listen((_) => loadPinnedMessages(), onError: onError));
  }

  void _onLive(List<ChatMessage> live) {
    // Les messages qui sortent de la fenêtre restent visibles (pagination).
    final liveIds = live.map((m) => m.id).toSet();
    final firstLive = live.isEmpty ? null : live.first.createdAt;
    final dropped = _live.where((m) =>
        !liveIds.contains(m.id) && (firstLive == null || m.createdAt.isBefore(firstLive)));
    final olderIds = _older.map((m) => m.id).toSet();
    _older = [..._older, ...dropped.where((m) => !olderIds.contains(m.id))]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _live = live;
    _rebuild();
    _isLoading = false;
    _notify();
  }

  void _rebuild() {
    final liveIds = _live.map((m) => m.id).toSet();
    _messages = [..._older.where((m) => !liveIds.contains(m.id)), ..._live];
  }

  // ─── Loading ─────────────────────────────────────────────────────────────

  Future<void> loadMessages() async {
    _isLoading = true;
    _errorMessage = null;
    _notify();

    try {
      final msgs = await _repo.getMessages(groupId, userId: currentUserId, limit: _pageSize);
      if (_live.isEmpty) {
        _live = msgs;
        _rebuild();
      }
      _hasMore = msgs.length >= _pageSize;
    } catch (e) {
      debugPrint('loadMessages: $e');
      _errorMessage = 'Erreur lors du chargement des messages.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> loadMoreMessages() async {
    if (!_hasMore || _isLoading || _messages.isEmpty) return;

    try {
      final older = await _repo.getMessages(
        groupId,
        userId: currentUserId,
        limit: _pageSize,
        beforeId: _messages.first.id,
      );
      final known = _messages.map((m) => m.id).toSet();
      _older = [...older.where((m) => !known.contains(m.id)), ..._older];
      _hasMore = older.length >= _pageSize;
      _rebuild();
      _notify();
    } catch (_) {}
  }

  Future<void> loadPinnedMessages() async {
    try {
      _pinnedMessages = await _repo.getPinnedMessages(groupId, currentUserId);
      _notify();
    } catch (_) {}
  }

  // ─── Sending ──────────────────────────────────────────────────────────────

  Future<bool> sendTextMessage(String content) async {
    final text = content.trim();
    if (text.isEmpty) return false;
    if (_isSending) return false;
    if (currentUserId.isEmpty) {
      _errorMessage = 'Vous devez être connecté.';
      _notify();
      return false;
    }

    _isSending = true;
    _notify();

    try {
      if (_isEditing && _editingMessage != null) {
        final ok = await _repo.editMessage(
          groupId: groupId,
          messageId: _editingMessage!.id,
          userId: currentUserId,
          newContent: text,
        );
        if (ok) await _refreshMessage(_editingMessage!.id);
        clearCompose();
        return ok;
      }
      final msg = await _repo.sendMessage(
        groupId: groupId,
        senderId: currentUserId,
        content: text,
        replyToMessageId: _replyingTo?.id,
      );
      if (msg == null) {
        _errorMessage = 'Vous devez être membre du groupe pour écrire.';
        return false;
      }
      _upsert(msg);
      clearCompose();
      return true;
    } catch (_) {
      _errorMessage = "Erreur lors de l'envoi du message.";
      return false;
    } finally {
      _isSending = false;
      _notify();
    }
  }

  Future<bool> pickAndSendFile() async {
    if (_isSending) return false;

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: AttachmentStorageService.allowedExtensions,
      );
      if (files.isEmpty) return false;
      final picked = files.first;

      _isSending = true;
      _notify();

      final bytes = await picked.readAsBytes();
      final stored = await _storage.storeBytes(bytes, picked.name, groupId);

      final msg = await _repo.sendAttachmentMessage(
        groupId: groupId,
        senderId: currentUserId,
        originalFilename: picked.name,
        localPath: stored.relativePath,
        mimeType: stored.mimeType,
        fileSize: stored.fileSize,
        inlineBytes: bytes,
        replyToMessageId: _replyingTo?.id,
      );

      if (msg != null) {
        _upsert(msg);
        clearCompose();
        if (msg.attachment?.hasRemoteCopy == false) {
          _errorMessage = 'Fichier envoyé. Au-delà de '
              '${GroupChatRepository.inlineMaxBytes ~/ 1024} Ko, il reste '
              'consultable uniquement sur cet appareil.';
        }
        _notify();
        return true;
      }
      _errorMessage = 'Vous devez être membre du groupe pour envoyer un fichier.';
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _notify();
      return false;
    } finally {
      _isSending = false;
      _notify();
    }
  }

  Future<bool> sendPoll({
    required String question,
    required List<String> options,
  }) async {
    if (_isSending) return false;

    _isSending = true;
    _notify();

    try {
      final msg = await _repo.sendPollMessage(
        groupId: groupId,
        senderId: currentUserId,
        question: question,
        options: options,
      );

      if (msg != null) {
        final poll = await _repo.getPollForMessage(groupId, msg.id, currentUserId);
        if (poll != null) _pollCache[msg.id] = poll;
        _upsert(msg);
        _notify();
        return true;
      }
      return false;
    } catch (_) {
      _errorMessage = 'Erreur lors de la création du sondage.';
      return false;
    } finally {
      _isSending = false;
      _notify();
    }
  }

  // ─── Editing / deleting ────────────────────────────────────────────────────

  void startEdit(ChatMessage message) {
    if (message.senderId != currentUserId) return;
    _isEditing = true;
    _editingMessage = message;
    _notify();
  }

  Future<bool> deleteMessage(String messageId) async {
    final ok = await _repo.deleteMessage(
      groupId: groupId,
      messageId: messageId,
      userId: currentUserId,
    );
    if (ok) await _refreshMessage(messageId);
    return ok;
  }

  // ─── Reactions ────────────────────────────────────────────────────────────

  Future<void> toggleReaction(String messageId, String emoji) async {
    try {
      await _repo.toggleReaction(
        groupId: groupId,
        messageId: messageId,
        userId: currentUserId,
        emoji: emoji,
      );
      await _refreshMessage(messageId);
    } catch (e) {
      debugPrint('toggleReaction: $e');
      _errorMessage = 'Réaction impossible.';
      _notify();
    }
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
      groupId: groupId,
      pollId: pollId,
      optionId: optionId,
      userId: currentUserId,
    );
    if (ok) await _refreshPoll(messageId);
    return ok;
  }

  Future<bool> closePoll(String pollId, String messageId) async {
    final ok = isOwner
        ? await _repo.closePollForce(groupId, pollId)
        : await _repo.closePoll(groupId: groupId, pollId: pollId, requestedBy: currentUserId);
    if (ok) await _refreshPoll(messageId);
    return ok;
  }

  Future<void> _refreshPoll(String messageId) async {
    final poll = await _repo.getPollForMessage(groupId, messageId, currentUserId);
    if (poll != null) {
      _pollCache[messageId] = poll;
      _notify();
    }
  }

  // ─── File actions ─────────────────────────────────────────────────────────

  /// Fichier local de la pièce jointe ; s'il est absent (fichier envoyé par
  /// un autre membre), il est téléchargé depuis Firestore quand une copie
  /// existe. `null` si le fichier n'est disponible que chez l'expéditeur.
  Future<String?> ensureLocalFile(ChatAttachment attachment) async {
    try {
      final file = await _storage.resolveFile(attachment.localPath);
      if (file.existsSync()) return file.path;
      if (!attachment.hasRemoteCopy) return null;
      final bytes = await _repo.downloadAttachment(groupId, attachment.messageId);
      if (bytes == null) return null;
      final written = await _storage.writeAt(attachment.localPath, bytes);
      return written.path;
    } catch (e) {
      debugPrint('ensureLocalFile: $e');
      return null;
    }
  }

  String _unavailableMessage(ChatAttachment a) => a.hasRemoteCopy
      ? 'Fichier introuvable.'
      : "Fichier volumineux : disponible uniquement sur l'appareil de l'expéditeur.";

  Future<void> openAttachment(ChatAttachment attachment) async {
    final path = await ensureLocalFile(attachment);
    if (path == null) {
      _errorMessage = _unavailableMessage(attachment);
      _notify();
      return;
    }
    try {
      await OpenFilex.open(path);
    } catch (e) {
      _errorMessage = "Impossible d'ouvrir le fichier.";
      _notify();
    }
  }

  Future<void> shareAttachment(ChatAttachment attachment) async {
    final path = await ensureLocalFile(attachment);
    if (path == null) {
      _errorMessage = _unavailableMessage(attachment);
      _notify();
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: attachment.originalFilename),
      );
    } catch (e) {
      _errorMessage = 'Impossible de partager le fichier.';
      _notify();
    }
  }

  // ─── Media gallery helper ─────────────────────────────────────────────────

  /// Returns the absolute path for [relativePath] if the file exists, else null.
  /// Télécharge la copie Firestore si nécessaire.
  Future<String?> resolveAttachmentPath(String relativePath) async {
    for (final m in _messages) {
      final a = m.attachment;
      if (a != null && a.localPath == relativePath) return ensureLocalFile(a);
    }
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
    _notify();
  }

  Future<void> search(String query) async {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      _searchResults = [];
      _notify();
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
    _notify();
  }

  // ─── Compose state management ─────────────────────────────────────────────

  void setReplyTo(ChatMessage? message) {
    _replyingTo = message;
    _isEditing = false;
    _editingMessage = null;
    _notify();
  }

  void clearCompose() {
    _replyingTo = null;
    _isEditing = false;
    _editingMessage = null;
    _notify();
  }

  void clearError() {
    _errorMessage = null;
    _notify();
  }

  // ─── Shared files ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSharedFiles() async {
    return _repo.getSharedFiles(groupId);
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  void _upsert(ChatMessage msg) {
    final idx = _live.indexWhere((m) => m.id == msg.id);
    if (idx >= 0) {
      _live[idx] = msg;
    } else if (!_older.any((m) => m.id == msg.id)) {
      _live = [..._live, msg];
    }
    _rebuild();
  }

  Future<void> _refreshMessage(String messageId) async {
    try {
      final fresh = await _repo.getMessage(groupId, messageId);
      if (fresh == null) return;
      final olderIdx = _older.indexWhere((m) => m.id == messageId);
      if (olderIdx >= 0) {
        _older[olderIdx] = fresh;
      } else {
        _upsert(fresh);
      }
      _rebuild();
    } catch (_) {}
    _notify();
  }
}
