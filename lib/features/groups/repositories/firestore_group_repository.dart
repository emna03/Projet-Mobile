import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../gestion_user/models/public_profile.dart';
import '../../gestion_user/repositories/profile_directory.dart';
import '../models/group.dart';
import '../models/join_request.dart';
import 'group_repository.dart';

/// Implémentation Firestore du dépôt des groupes.
///
/// Modèle de données (voir aussi `firestore.rules`) :
/// - `groups/{groupId}` : name, description, level, isPublic, maxMembers,
///   ownerId (UID Firebase), memberIds (UID, propriétaire inclus), createdAt.
/// - `group_join_requests/{groupId}__{userId}` : groupId, userId, userName,
///   ownerId, status (pending|accepted|rejected), createdAt, reviewedAt.
///
/// Les opérations sensibles (adhésion, capacité, acceptation) sont faites
/// dans des transactions ; les règles Firestore les revérifient côté serveur.
class FirestoreGroupRepository implements GroupRepository {
  FirestoreGroupRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ProfileDirectory? profiles,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _profiles = profiles ?? ProfileDirectory.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final ProfileDirectory _profiles;

  static const groupsCollection = 'groups';
  static const requestsCollection = 'group_join_requests';

  /// Sous-collections supprimées avec le groupe (module chat).
  static const groupSubcollections = [
    'messages',
    'polls',
    'pinned',
    'attachmentData',
  ];

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection(groupsCollection);
  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection(requestsCollection);

  static String requestDocId(String groupId, String userId) => '${groupId}__$userId';

  String get _me => _auth.currentUser?.uid ?? '';

  // ─── Mapping ───────────────────────────────────────────────────────────────

  static DateTime _date(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  static List<String> _ids(Map<String, dynamic> data) =>
      List<String>.from(data['memberIds'] as List? ?? const []);

  Group _mapGroup(String id, Map<String, dynamic> d, Map<String, PublicProfile> profiles) {
    return Group(
      id: id,
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      level: d['level'] as String? ?? '',
      isPublic: d['isPublic'] as bool? ?? true,
      maxMembers: (d['maxMembers'] as num?)?.toInt() ?? 10,
      ownerId: d['ownerId'] as String? ?? '',
      members: [
        for (final uid in _ids(d)) profiles[uid] ?? PublicProfile.unknown(uid),
      ],
      createdAt: _date(d['createdAt']),
    );
  }

  JoinRequest _mapRequest(String id, Map<String, dynamic> d) {
    return JoinRequest(
      id: id,
      groupId: d['groupId'] as String,
      userId: d['userId'] as String,
      status: JoinRequestStatus.values.asNameMap()[d['status']] ?? JoinRequestStatus.pending,
      createdAt: _date(d['createdAt']),
      reviewedAt: d['reviewedAt'] == null ? null : _date(d['reviewedAt']),
      userName: d['userName'] as String?,
    );
  }

  /// Traduit les erreurs Firestore en messages lisibles.
  static String describe(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'Action non autorisée.';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'Réseau indisponible. Réessayez.';
        case 'not-found':
          return 'Groupe introuvable.';
      }
      return e.message ?? 'Erreur Firestore (${e.code}).';
    }
    return e.toString();
  }

  // ─── Utilisateurs ─────────────────────────────────────────────────────────

  @override
  Future<List<PublicProfile>> getAllUsers() => _profiles.getAll();

  @override
  Future<PublicProfile?> getUserById(String id) => _profiles.getProfile(id);

  @override
  Future<List<PublicProfile>> getMembersOfGroup(String groupId) async {
    final snap = await _groups.doc(groupId).get();
    if (!snap.exists) return const [];
    final ids = _ids(snap.data()!);
    final profiles = await _profiles.getProfiles(ids);
    return [for (final id in ids) profiles[id]!];
  }

  // ─── Groupes ──────────────────────────────────────────────────────────────

  @override
  Future<List<Group>> getGroups() async {
    final snap = await _groups.orderBy('createdAt', descending: true).get();
    final allIds = <String>{for (final d in snap.docs) ..._ids(d.data())};
    final profiles = await _profiles.getProfiles(allIds);
    return [for (final d in snap.docs) _mapGroup(d.id, d.data(), profiles)];
  }

  @override
  Future<Group?> getGroupById(String id) async {
    final snap = await _groups.doc(id).get();
    if (!snap.exists) return null;
    final profiles = await _profiles.getProfiles(_ids(snap.data()!));
    return _mapGroup(snap.id, snap.data()!, profiles);
  }

  @override
  Future<Group> addGroup(Group group) async {
    final me = _me;
    if (me.isEmpty || group.ownerId != me) {
      throw StateError('Vous devez être connecté pour créer un groupe.');
    }
    final memberIds = <String>{me, ...group.members.map((m) => m.id)}.toList();
    if (memberIds.length > group.maxMembers) {
      throw StateError('Le nombre de membres dépasse la capacité.');
    }
    // Identifiant attribué par Firestore : unique entre tous les appareils.
    final ref = _groups.doc();
    final write = ref.set({
      'name': group.name,
      'description': group.description,
      'level': group.level,
      'isPublic': group.isPublic,
      'maxMembers': group.maxMembers,
      'ownerId': me,
      'memberIds': memberIds,
      'createdAt': Timestamp.fromDate(group.createdAt),
    });

    // Firestore applique l'écriture tout de suite dans son cache local puis
    // la synchronise. On n'attend la confirmation du serveur que brièvement :
    // un refus (règles) arrivant plus tard retire le groupe via le flux temps
    // réel. Une erreur immédiate est remontée normalement.
    var failed = false;
    Object? error;
    write.catchError((Object e) {
      failed = true;
      error = e;
      debugPrint('addGroup (serveur): $e');
    });
    await Future.any([
      write.then((_) {}, onError: (_) {}),
      Future<void>.delayed(const Duration(milliseconds: 1500)),
    ]);
    if (failed) throw StateError(describe(error!));

    // Groupe construit localement (profils déjà en mémoire) : pas de relecture.
    final known = {for (final m in group.members) m.id: m};
    final missing = memberIds.where((id) => !known.containsKey(id));
    if (missing.isNotEmpty) known.addAll(await _profiles.getProfiles(missing));
    return group.copyWith(
      id: ref.id,
      ownerId: me,
      members: [for (final id in memberIds) known[id] ?? PublicProfile.unknown(id)],
    );
  }

  @override
  Future<Group> updateGroup(Group group) async {
    final me = _me;
    final ref = _groups.doc(group.id);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) throw StateError('Groupe introuvable.');
      if (snap.data()!['ownerId'] != me) {
        throw StateError('Seul le créateur peut modifier le groupe.');
      }
      final memberIds = <String>{me, ...group.members.map((m) => m.id)}.toList();
      if (memberIds.length > group.maxMembers) {
        throw StateError('Le nombre de membres dépasse la capacité.');
      }
      txn.update(ref, {
        'name': group.name,
        'description': group.description,
        'level': group.level,
        'isPublic': group.isPublic,
        'maxMembers': group.maxMembers,
        'memberIds': memberIds,
      });
    });
    return (await getGroupById(group.id))!;
  }

  @override
  Future<bool> deleteGroup(String id) async {
    final me = _me;
    final ref = _groups.doc(id);
    final snap = await ref.get();
    if (!snap.exists) return false;
    if (snap.data()!['ownerId'] != me) return false;

    // Firestore ne supprime pas les sous-collections en cascade : on les vide
    // avant le document (les règles l'autorisent au propriétaire).
    for (final sub in groupSubcollections) {
      await _deleteQuery(ref.collection(sub));
    }
    final requests = await _requests.where('ownerId', isEqualTo: me).get();
    await _deleteDocs(requests.docs.where((d) => d.data()['groupId'] == id).map((d) => d.reference));
    await ref.delete();
    return true;
  }

  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snap = await query.limit(400).get();
      if (snap.docs.isEmpty) return;
      await _deleteDocs(snap.docs.map((d) => d.reference));
      if (snap.docs.length < 400) return;
    }
  }

  Future<void> _deleteDocs(Iterable<DocumentReference> refs) async {
    final list = refs.toList();
    for (var i = 0; i < list.length; i += 400) {
      final batch = _db.batch();
      for (final r in list.skip(i).take(400)) {
        batch.delete(r);
      }
      await batch.commit();
    }
  }

  // ─── Adhésion ─────────────────────────────────────────────────────────────

  @override
  Future<bool> isMember(String groupId, String userId) async {
    final snap = await _groups.doc(groupId).get();
    return snap.exists && _ids(snap.data()!).contains(userId);
  }

  @override
  Future<String?> joinGroup(String groupId, String userId) async {
    final ref = _groups.doc(groupId);
    try {
      return await _db.runTransaction<String?>((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return 'Groupe introuvable.';
        final data = snap.data()!;
        final ids = _ids(data);
        if (ids.contains(userId)) return 'Vous êtes déjà membre du groupe.';
        final isOwnerAction = data['ownerId'] == _me && userId != _me;
        if (!isOwnerAction) {
          if (userId != _me) return 'Action non autorisée.';
          if (data['isPublic'] != true) {
            return 'Ce groupe est privé : envoyez une demande d\'adhésion.';
          }
        }
        final max = (data['maxMembers'] as num?)?.toInt() ?? 10;
        if (ids.length >= max) return 'Le groupe est complet.';
        txn.update(ref, {'memberIds': [...ids, userId]});
        return null;
      });
    } catch (e) {
      return describe(e);
    }
  }

  @override
  Future<String?> leaveGroup(String groupId, String userId) async {
    final ref = _groups.doc(groupId);
    try {
      return await _db.runTransaction<String?>((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return 'Groupe introuvable.';
        final data = snap.data()!;
        if (data['ownerId'] == userId) {
          return 'Le créateur ne peut pas quitter son propre groupe.';
        }
        final ids = _ids(data);
        if (!ids.contains(userId)) return null;
        txn.update(ref, {'memberIds': ids.where((id) => id != userId).toList()});
        return null;
      });
    } catch (e) {
      return describe(e);
    }
  }

  @override
  Future<String?> removeMember(String groupId, String userId) async {
    final ref = _groups.doc(groupId);
    try {
      return await _db.runTransaction<String?>((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return 'Groupe introuvable.';
        final data = snap.data()!;
        if (data['ownerId'] != _me) return 'Seul le créateur peut retirer un membre.';
        if (data['ownerId'] == userId) {
          return 'Le créateur du groupe ne peut pas être retiré.';
        }
        txn.update(ref, {'memberIds': _ids(data).where((id) => id != userId).toList()});
        return null;
      });
    } catch (e) {
      return describe(e);
    }
  }

  // ─── Demandes d'adhésion ──────────────────────────────────────────────────

  @override
  Future<String?> sendJoinRequest(String groupId, String userId) async {
    if (userId != _me) return 'Action non autorisée.';
    final groupRef = _groups.doc(groupId);
    final reqRef = _requests.doc(requestDocId(groupId, userId));
    try {
      final profile = await _profiles.getProfile(userId);
      return await _db.runTransaction<String?>((txn) async {
        final g = await txn.get(groupRef);
        if (!g.exists) return 'Groupe introuvable.';
        final data = g.data()!;
        if (_ids(data).contains(userId)) return 'Vous êtes déjà membre du groupe.';
        final existing = await txn.get(reqRef);
        if (existing.exists && existing.data()!['status'] == 'pending') {
          return 'Une demande est déjà en attente.';
        }
        txn.set(reqRef, {
          'groupId': groupId,
          'userId': userId,
          'userName': profile?.name ?? 'Utilisateur',
          'ownerId': data['ownerId'],
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'reviewedAt': null,
        });
        return null;
      });
    } catch (e) {
      return describe(e);
    }
  }

  @override
  Future<bool> cancelJoinRequest(String groupId, String userId) async {
    final ref = _requests.doc(requestDocId(groupId, userId));
    try {
      final snap = await ref.get();
      if (!snap.exists || snap.data()!['status'] != 'pending') return false;
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('cancelJoinRequest: $e');
      return false;
    }
  }

  /// Demandes en attente des groupes dont je suis propriétaire.
  Future<List<JoinRequest>> _pendingForOwner(String ownerId) async {
    final snap = await _requests.where('ownerId', isEqualTo: ownerId).get();
    return snap.docs
        .where((d) => d.data()['status'] == 'pending')
        .map((d) => _mapRequest(d.id, d.data()))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<List<JoinRequest>> getPendingRequests(String groupId) async {
    final mine = await _pendingForOwner(_me);
    return mine.where((r) => r.groupId == groupId).toList();
  }

  @override
  Future<JoinRequest?> getPendingRequest(String groupId, String userId) async {
    final snap = await _requests.doc(requestDocId(groupId, userId)).get();
    if (!snap.exists || snap.data()!['status'] != 'pending') return null;
    return _mapRequest(snap.id, snap.data()!);
  }

  @override
  Future<List<JoinRequest>> getPendingRequestsForUser(String userId) async {
    final snap = await _requests.where('userId', isEqualTo: userId).get();
    return snap.docs
        .where((d) => d.data()['status'] == 'pending')
        .map((d) => _mapRequest(d.id, d.data()))
        .toList();
  }

  @override
  Future<String?> acceptJoinRequest(String requestId, String groupId, String userId) async {
    final groupRef = _groups.doc(groupId);
    final reqRef = _requests.doc(requestId);
    try {
      return await _db.runTransaction<String?>((txn) async {
        final g = await txn.get(groupRef);
        final r = await txn.get(reqRef);
        if (!g.exists) return 'Groupe introuvable.';
        if (!r.exists || r.data()!['status'] != 'pending') {
          return 'Cette demande n\'est plus en attente.';
        }
        final data = g.data()!;
        if (data['ownerId'] != _me) return 'Seul le créateur peut accepter une demande.';
        final ids = _ids(data);
        final max = (data['maxMembers'] as num?)?.toInt() ?? 10;
        if (!ids.contains(userId) && ids.length >= max) {
          return 'Le groupe est complet. Impossible d\'accepter cette demande.';
        }
        if (!ids.contains(userId)) {
          txn.update(groupRef, {'memberIds': [...ids, userId]});
        }
        txn.update(reqRef, {
          'status': 'accepted',
          'reviewedAt': FieldValue.serverTimestamp(),
        });
        return null;
      });
    } catch (e) {
      return describe(e);
    }
  }

  @override
  Future<bool> rejectJoinRequest(String requestId) async {
    try {
      await _requests.doc(requestId).update({
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('rejectJoinRequest: $e');
      return false;
    }
  }

  // ─── Temps réel ───────────────────────────────────────────────────────────

  @override
  Stream<void>? watchChanges(String userId) {
    if (userId.isEmpty) return null;
    late final StreamController<void> controller;
    final subs = <StreamSubscription<Object?>>[];
    void emit(Object? _) {
      if (!controller.isClosed) controller.add(null);
    }

    void onError(Object e) => debugPrint('FirestoreGroupRepository.watch: $e');
    controller = StreamController<void>(
      onListen: () {
        subs
          ..add(_groups.snapshots().skip(1).listen(emit, onError: onError))
          ..add(_requests.where('userId', isEqualTo: userId).snapshots().skip(1).listen(emit, onError: onError))
          ..add(_requests.where('ownerId', isEqualTo: userId).snapshots().skip(1).listen(emit, onError: onError));
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }
}
