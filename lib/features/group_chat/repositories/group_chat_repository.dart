import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../gestion_user/models/public_profile.dart';
import '../../gestion_user/repositories/profile_directory.dart';
import '../models/chat_message.dart';
import '../models/group_poll.dart';

/// Accès aux données du chat de groupe, stockées dans Firestore pour que
/// tous les membres les voient en temps réel, sur tous leurs appareils.
///
/// Structure (sous `groups/{groupId}`, voir `firestore.rules`) :
/// - `messages/{messageId}` : senderId, senderName, senderPhotoUrl, type
///   (text|attachment|poll), content, reply*, createdAt, updatedAt, deletedAt,
///   reactions `{uid: {name, emojis: [..]}}`, attachment `{...}`.
/// - `polls/{messageId}` : question, createdBy, createdAt, closedAt,
///   options `[{id, text, order}]`, votes `{uid: optionId}`.
/// - `pinned/{messageId}` : pinnedBy, pinnedAt (propriétaire uniquement).
/// - `attachmentData/{messageId}` : copie binaire des petits fichiers.
///
/// Les contrôles (membre du groupe, auteur du message, propriétaire) sont
/// faits ici ET dans les règles Firestore : l'interface n'est jamais la
/// seule protection.
class GroupChatRepository {
  GroupChatRepository({FirebaseFirestore? firestore, ProfileDirectory? profiles})
      : _dbOverride = firestore,
        _profilesOverride = profiles;

  final FirebaseFirestore? _dbOverride;
  final ProfileDirectory? _profilesOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  ProfileDirectory get _profiles => _profilesOverride ?? ProfileDirectory.instance;

  /// Taille maximale d'un fichier recopié dans Firestore (document ≤ 1 Mio).
  static const inlineMaxBytes = 700 * 1024;

  DocumentReference<Map<String, dynamic>> _group(String groupId) =>
      _db.collection('groups').doc(groupId);
  CollectionReference<Map<String, dynamic>> _messages(String groupId) =>
      _group(groupId).collection('messages');
  CollectionReference<Map<String, dynamic>> _polls(String groupId) =>
      _group(groupId).collection('polls');
  CollectionReference<Map<String, dynamic>> _pinned(String groupId) =>
      _group(groupId).collection('pinned');
  CollectionReference<Map<String, dynamic>> _attachmentData(String groupId) =>
      _group(groupId).collection('attachmentData');

  // ─── Contrôle d'accès ─────────────────────────────────────────────────────

  /// `true` si [userId] est membre (ou propriétaire) de [groupId].
  Future<bool> canAccess(String groupId, String userId) async {
    if (userId.isEmpty) return false;
    final snap = await _group(groupId).get();
    if (!snap.exists) return false;
    final ids = List<String>.from(snap.data()!['memberIds'] as List? ?? const []);
    return ids.contains(userId);
  }

  // ─── Lecture ──────────────────────────────────────────────────────────────

  /// Page de [limit] messages (ordre chronologique), avant [beforeId].
  Future<List<ChatMessage>> getMessages(
    String groupId, {
    String userId = '',
    int limit = 40,
    String? beforeId,
  }) async {
    Query<Map<String, dynamic>> q =
        _messages(groupId).orderBy('createdAt', descending: true).limit(limit);
    if (beforeId != null) {
      final anchor = await _messages(groupId).doc(beforeId).get();
      if (anchor.exists) q = q.startAfterDocument(anchor);
    }
    final snap = await q.get();
    return snap.docs.reversed.map(_mapMessage).toList();
  }

  /// Les [limit] derniers messages, mis à jour en temps réel.
  Stream<List<ChatMessage>> watchMessages(String groupId, {int limit = 40}) {
    return _messages(groupId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.reversed.map(_mapMessage).toList());
  }

  Future<ChatMessage?> getMessage(String groupId, String messageId) async {
    final snap = await _messages(groupId).doc(messageId).get();
    return snap.exists ? _mapMessage(snap) : null;
  }

  // ─── Envoi ────────────────────────────────────────────────────────────────

  Future<Map<String, Object?>> _baseMessage({
    required String groupId,
    required String senderId,
    required String type,
    required String content,
    String? replyToMessageId,
  }) async {
    final PublicProfile? profile = await _profiles.getProfile(senderId);
    String? replyContent;
    String? replyName;
    if (replyToMessageId != null) {
      final reply = await getMessage(groupId, replyToMessageId);
      if (reply != null) {
        replyContent = reply.isDeleted ? 'Message supprimé' : reply.content;
        replyName = reply.senderName;
      }
    }
    return {
      'senderId': senderId,
      'senderName': profile?.name ?? 'Utilisateur',
      'senderPhotoUrl': profile?.photoUrl,
      'type': type,
      'content': content,
      'replyToMessageId': replyToMessageId,
      'replyToContent': replyContent,
      'replyToSenderName': replyName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': null,
      'deletedAt': null,
      'reactions': <String, Object?>{},
    };
  }

  /// Envoie un message texte. Renvoie `null` si l'expéditeur n'est pas membre.
  Future<ChatMessage?> sendMessage({
    required String groupId,
    required String senderId,
    required String content,
    String? replyToMessageId,
  }) async {
    if (!await canAccess(groupId, senderId)) return null;
    final ref = _messages(groupId).doc();
    await ref.set(await _baseMessage(
      groupId: groupId,
      senderId: senderId,
      type: 'text',
      content: content,
      replyToMessageId: replyToMessageId,
    ));
    return getMessage(groupId, ref.id);
  }

  /// Envoie une pièce jointe. Le fichier reste stocké localement
  /// ([localPath]) ; s'il est petit ([inlineBytes] ≤ [inlineMaxBytes]), une
  /// copie est aussi placée dans Firestore pour les autres membres.
  Future<ChatMessage?> sendAttachmentMessage({
    required String groupId,
    required String senderId,
    required String originalFilename,
    required String localPath,
    required String mimeType,
    required int fileSize,
    Uint8List? inlineBytes,
    String? replyToMessageId,
  }) async {
    if (!await canAccess(groupId, senderId)) return null;
    final ref = _messages(groupId).doc();
    final remote = inlineBytes != null && inlineBytes.length <= inlineMaxBytes;
    final data = await _baseMessage(
      groupId: groupId,
      senderId: senderId,
      type: 'attachment',
      content: originalFilename,
      replyToMessageId: replyToMessageId,
    );
    data['attachment'] = {
      'id': 'att_${ref.id}',
      'originalFilename': originalFilename,
      'localPath': localPath,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'hasRemoteCopy': remote,
    };
    final batch = _db.batch();
    if (remote) {
      batch.set(_attachmentData(groupId).doc(ref.id), {
        'senderId': senderId,
        'fileName': originalFilename,
        'mimeType': mimeType,
        'data': Blob(inlineBytes),
      });
    }
    batch.set(ref, data);
    await batch.commit();
    return getMessage(groupId, ref.id);
  }

  /// Contenu binaire d'une pièce jointe recopiée dans Firestore.
  Future<Uint8List?> downloadAttachment(String groupId, String messageId) async {
    final snap = await _attachmentData(groupId).doc(messageId).get();
    final blob = snap.data()?['data'];
    return blob is Blob ? blob.bytes : null;
  }

  /// Crée un sondage (2 à 8 options). L'identifiant du sondage est celui du
  /// message qui l'affiche.
  Future<ChatMessage?> sendPollMessage({
    required String groupId,
    required String senderId,
    required String question,
    required List<String> options,
  }) async {
    if (!await canAccess(groupId, senderId)) return null;
    if (options.length < 2 || options.length > 8) return null;
    final ref = _messages(groupId).doc();
    final batch = _db.batch()
      ..set(ref, await _baseMessage(
        groupId: groupId,
        senderId: senderId,
        type: 'poll',
        content: question,
      ))
      ..set(_polls(groupId).doc(ref.id), {
        'question': question,
        'createdBy': senderId,
        'createdAt': FieldValue.serverTimestamp(),
        'closedAt': null,
        'options': [
          for (var i = 0; i < options.length; i++)
            {'id': 'opt_$i', 'text': options[i], 'order': i},
        ],
        'votes': <String, Object?>{},
      });
    await batch.commit();
    return getMessage(groupId, ref.id);
  }

  // ─── Modification / suppression (auteur uniquement) ───────────────────────

  Future<bool> editMessage({
    required String groupId,
    required String messageId,
    required String userId,
    required String newContent,
  }) async {
    final ref = _messages(groupId).doc(messageId);
    try {
      return await _db.runTransaction<bool>((txn) async {
        final snap = await txn.get(ref);
        final d = snap.data();
        if (d == null || d['senderId'] != userId || d['deletedAt'] != null) return false;
        txn.update(ref, {'content': newContent, 'updatedAt': FieldValue.serverTimestamp()});
        return true;
      });
    } catch (e) {
      debugPrint('editMessage: $e');
      return false;
    }
  }

  /// Suppression « douce » : le message reste avec un texte neutre.
  Future<bool> deleteMessage({
    required String groupId,
    required String messageId,
    required String userId,
  }) async {
    final ref = _messages(groupId).doc(messageId);
    try {
      return await _db.runTransaction<bool>((txn) async {
        final snap = await txn.get(ref);
        final d = snap.data();
        if (d == null || d['senderId'] != userId || d['deletedAt'] != null) return false;
        txn.update(ref, {
          'content': 'Ce message a été supprimé.',
          'deletedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (e) {
      debugPrint('deleteMessage: $e');
      return false;
    }
  }

  // ─── Réactions ────────────────────────────────────────────────────────────

  /// Ajoute ou retire [emoji] pour [userId] (transaction : pas de perte en
  /// cas de réactions simultanées).
  Future<void> toggleReaction({
    required String groupId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final ref = _messages(groupId).doc(messageId);
    final profile = await _profiles.getProfile(userId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final d = snap.data();
      if (d == null) return;
      final reactions = Map<String, dynamic>.from(d['reactions'] as Map? ?? const {});
      final mine = Map<String, dynamic>.from(reactions[userId] as Map? ?? const {});
      final emojis = List<String>.from(mine['emojis'] as List? ?? const []);
      emojis.contains(emoji) ? emojis.remove(emoji) : emojis.add(emoji);
      final field = FieldPath(['reactions', userId]);
      if (emojis.isEmpty) {
        txn.update(ref, {field: FieldValue.delete()});
      } else {
        txn.update(ref, {
          field: {'name': profile?.name ?? 'Utilisateur', 'emojis': emojis},
        });
      }
    });
  }

  // ─── Messages épinglés (propriétaire du groupe) ───────────────────────────

  Future<List<ChatMessage>> getPinnedMessages(String groupId, String userId) async {
    final pins = await _pinned(groupId).orderBy('pinnedAt', descending: true).get();
    final result = <ChatMessage>[];
    for (final p in pins.docs) {
      final m = await getMessage(groupId, p.id);
      if (m != null) result.add(m);
    }
    return result;
  }

  Stream<void> watchPinned(String groupId) =>
      _pinned(groupId).snapshots().map((_) {});

  Future<bool> pinMessage({
    required String groupId,
    required String messageId,
    required String pinnedBy,
    required String ownerId,
  }) async {
    if (pinnedBy != ownerId) return false;
    try {
      await _pinned(groupId).doc(messageId).set({
        'pinnedBy': pinnedBy,
        'pinnedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('pinMessage: $e');
      return false;
    }
  }

  Future<bool> unpinMessage({
    required String groupId,
    required String messageId,
    required String requestedBy,
    required String ownerId,
  }) async {
    if (requestedBy != ownerId) return false;
    try {
      await _pinned(groupId).doc(messageId).delete();
      return true;
    } catch (e) {
      debugPrint('unpinMessage: $e');
      return false;
    }
  }

  // ─── Sondages ─────────────────────────────────────────────────────────────

  Future<GroupPoll?> getPollForMessage(String groupId, String messageId, String userId) async {
    final snap = await _polls(groupId).doc(messageId).get();
    if (!snap.exists) return null;
    return _mapPoll(groupId, snap, userId);
  }

  /// Tous les sondages du groupe (clé = id du message), en temps réel.
  Stream<Map<String, GroupPoll>> watchPolls(String groupId, String userId) {
    return _polls(groupId).snapshots().map((s) => {
          for (final d in s.docs) d.id: _mapPoll(groupId, d, userId),
        });
  }

  /// Vote (ou change de vote) — un seul choix par membre, sondage ouvert.
  Future<bool> vote({
    required String groupId,
    required String pollId,
    required String optionId,
    required String userId,
  }) async {
    final ref = _polls(groupId).doc(pollId);
    try {
      return await _db.runTransaction<bool>((txn) async {
        final snap = await txn.get(ref);
        final d = snap.data();
        if (d == null || d['closedAt'] != null) return false;
        final options = (d['options'] as List? ?? const []).cast<Map>();
        if (!options.any((o) => o['id'] == optionId)) return false;
        txn.update(ref, {FieldPath(['votes', userId]): optionId});
        return true;
      });
    } catch (e) {
      debugPrint('vote: $e');
      return false;
    }
  }

  /// Clôture par le créateur du sondage.
  Future<bool> closePoll({
    required String groupId,
    required String pollId,
    required String requestedBy,
  }) async {
    final snap = await _polls(groupId).doc(pollId).get();
    if (!snap.exists || snap.data()!['createdBy'] != requestedBy) return false;
    return closePollForce(groupId, pollId);
  }

  /// Clôture par le propriétaire du groupe (vérifié par les règles).
  Future<bool> closePollForce(String groupId, String pollId) async {
    final ref = _polls(groupId).doc(pollId);
    try {
      return await _db.runTransaction<bool>((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists || snap.data()!['closedAt'] != null) return false;
        txn.update(ref, {'closedAt': FieldValue.serverTimestamp()});
        return true;
      });
    } catch (e) {
      debugPrint('closePoll: $e');
      return false;
    }
  }

  // ─── Recherche ────────────────────────────────────────────────────────────

  /// Firestore n'a pas de recherche « LIKE » : filtrage local sur les 500
  /// derniers messages texte.
  Future<List<ChatMessage>> searchMessages({
    required String groupId,
    required String userId,
    required String query,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final snap = await _messages(groupId)
        .orderBy('createdAt', descending: true)
        .limit(500)
        .get();
    return snap.docs
        .map(_mapMessage)
        .where((m) =>
            !m.isDeleted &&
            m.messageType == MessageType.text &&
            m.content.toLowerCase().contains(q))
        .take(50)
        .toList();
  }

  // ─── Fichiers partagés ────────────────────────────────────────────────────

  /// Pièces jointes du groupe, au format attendu par la galerie du chat.
  Future<List<Map<String, dynamic>>> getSharedFiles(String groupId) async {
    final snap = await _messages(groupId).where('type', isEqualTo: 'attachment').get();
    final messages = snap.docs.map(_mapMessage).where((m) => !m.isDeleted && m.attachment != null).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      for (final m in messages)
        {
          'id': m.attachment!.id,
          'message_id': m.id,
          'original_filename': m.attachment!.originalFilename,
          'local_path': m.attachment!.localPath,
          'mime_type': m.attachment!.mimeType,
          'file_size': m.attachment!.fileSize,
          'has_remote_copy': m.attachment!.hasRemoteCopy,
          'sent_at': m.createdAt.toIso8601String(),
          'sender_id': m.senderId,
          'sender_name': m.senderName,
          'sender_color': m.senderAvatarColorIndex,
        },
    ];
  }

  // ─── Mapping ──────────────────────────────────────────────────────────────

  static DateTime? _dateOrNull(Object? v) => v is Timestamp ? v.toDate() : null;

  ChatMessage _mapMessage(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final senderId = d['senderId'] as String? ?? '';
    final createdAt = _dateOrNull(d['createdAt']) ?? DateTime.now();

    final reactions = <MessageReaction>[];
    final raw = Map<String, dynamic>.from(d['reactions'] as Map? ?? const {});
    raw.forEach((uid, value) {
      final entry = Map<String, dynamic>.from(value as Map? ?? const {});
      for (final emoji in List<String>.from(entry['emojis'] as List? ?? const [])) {
        reactions.add(MessageReaction(
          messageId: doc.id,
          userId: uid,
          userName: entry['name'] as String? ?? '',
          emoji: emoji,
          createdAt: createdAt,
        ));
      }
    });

    ChatAttachment? attachment;
    final a = d['attachment'];
    if (a is Map) {
      attachment = ChatAttachment(
        id: a['id'] as String? ?? 'att_${doc.id}',
        messageId: doc.id,
        originalFilename: a['originalFilename'] as String? ?? 'fichier',
        localPath: a['localPath'] as String? ?? '',
        mimeType: a['mimeType'] as String? ?? 'application/octet-stream',
        fileSize: (a['fileSize'] as num?)?.toInt() ?? 0,
        createdAt: createdAt,
        senderId: senderId,
        hasRemoteCopy: a['hasRemoteCopy'] == true,
      );
    }

    final photo = (d['senderPhotoUrl'] as String? ?? '').trim();
    return ChatMessage(
      id: doc.id,
      groupId: doc.reference.parent.parent?.id ?? '',
      senderId: senderId,
      senderName: d['senderName'] as String? ?? 'Utilisateur inconnu',
      senderAvatarColorIndex: PublicProfile.colorIndexFor(senderId),
      senderPhotoUrl: photo.isEmpty ? null : photo,
      messageType: switch (d['type']) {
        'attachment' => MessageType.attachment,
        'poll' => MessageType.poll,
        _ => MessageType.text,
      },
      content: d['content'] as String? ?? '',
      replyToMessageId: d['replyToMessageId'] as String?,
      replyToContent: d['replyToContent'] as String?,
      replyToSenderName: d['replyToSenderName'] as String?,
      createdAt: createdAt,
      updatedAt: _dateOrNull(d['updatedAt']),
      deletedAt: _dateOrNull(d['deletedAt']),
      reactions: reactions,
      attachment: attachment,
    );
  }

  GroupPoll _mapPoll(String groupId, DocumentSnapshot<Map<String, dynamic>> doc, String userId) {
    final d = doc.data() ?? const {};
    final votes = Map<String, dynamic>.from(d['votes'] as Map? ?? const {});
    final counts = <String, int>{};
    for (final optionId in votes.values) {
      counts[optionId as String] = (counts[optionId] ?? 0) + 1;
    }
    final myChoice = votes[userId] as String?;
    final options = (d['options'] as List? ?? const [])
        .cast<Map>()
        .map((o) => PollOption(
              id: o['id'] as String,
              pollId: doc.id,
              optionText: o['text'] as String? ?? '',
              displayOrder: (o['order'] as num?)?.toInt() ?? 0,
              voteCount: counts[o['id']] ?? 0,
              isSelectedByCurrentUser: o['id'] == myChoice,
            ))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return GroupPoll(
      id: doc.id,
      groupId: groupId,
      messageId: doc.id,
      question: d['question'] as String? ?? '',
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: _dateOrNull(d['createdAt']) ?? DateTime.now(),
      closedAt: _dateOrNull(d['closedAt']),
      options: options,
    );
  }
}
