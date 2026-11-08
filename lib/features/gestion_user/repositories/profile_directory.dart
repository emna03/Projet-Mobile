import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/public_profile.dart';
import '../models/user.dart';

/// Annuaire des profils publics (`users/{uid}` dans Firestore).
///
/// Permet aux modules Groupes et Chat d'afficher le vrai nom, le rôle et la
/// photo des autres membres, quel que soit l'appareil. Chaque utilisateur
/// ne peut écrire que son propre document (voir `firestore.rules`).
class ProfileDirectory {
  ProfileDirectory({FirebaseFirestore? firestore}) : _firestoreOverride = firestore;

  static final ProfileDirectory instance = ProfileDirectory();

  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  final Map<String, PublicProfile> _cache = {};

  /// Publie (ou met à jour) le profil public de l'utilisateur connecté.
  ///
  /// [photoUrl] : URL publique de la photo, si elle a été hébergée.
  /// Laisser `null` conserve la photo déjà publiée.
  Future<PublicProfile> publish({
    required String uid,
    required AppUser user,
    String? photoUrl,
  }) async {
    final profile = PublicProfile.fromAppUser(uid, user, photoUrl: photoUrl);
    final data = <String, Object?>{
      'displayName': profile.name,
      'role': profile.roleKey,
      'updatedAt': FieldValue.serverTimestamp(),
      'photoUrl': ?photoUrl,
    };
    await _users.doc(uid).set(data, SetOptions(merge: true));
    final fresh = await _users.doc(uid).get();
    final published = PublicProfile.fromFirestore(uid, fresh.data() ?? {});
    _cache[uid] = published;
    return published;
  }

  /// Retire la photo publiée (photo supprimée dans le profil).
  Future<void> clearPhoto(String uid) async {
    await _users.doc(uid).set({'photoUrl': null}, SetOptions(merge: true));
    final cached = _cache[uid];
    if (cached != null) {
      _cache[uid] = PublicProfile(
        id: cached.id,
        name: cached.name,
        email: cached.email,
        role: cached.role,
        roleKey: cached.roleKey,
        avatarColorIndex: cached.avatarColorIndex,
      );
    }
  }

  Future<PublicProfile?> getProfile(String uid, {bool refresh = false}) async {
    if (!refresh && _cache.containsKey(uid)) return _cache[uid];
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return null;
    final profile = PublicProfile.fromFirestore(uid, snap.data()!);
    _cache[uid] = profile;
    return profile;
  }

  /// Résout plusieurs UID (cache + requêtes `whereIn` par lots de 30).
  /// Les UID sans document donnent un profil « Utilisateur inconnu ».
  Future<Map<String, PublicProfile>> getProfiles(Iterable<String> uids) async {
    final wanted = uids.toSet();
    final missing = wanted.where((id) => !_cache.containsKey(id)).toList();
    for (var i = 0; i < missing.length; i += 30) {
      final chunk = missing.sublist(i, i + 30 > missing.length ? missing.length : i + 30);
      try {
        final snap = await _users.where(FieldPath.documentId, whereIn: chunk).get();
        for (final doc in snap.docs) {
          _cache[doc.id] = PublicProfile.fromFirestore(doc.id, doc.data());
        }
      } catch (e) {
        debugPrint('ProfileDirectory.getProfiles: $e');
      }
    }
    return {
      for (final id in wanted) id: _cache[id] ?? PublicProfile.unknown(id),
    };
  }

  /// Tous les profils publics (sélection de membres par un propriétaire).
  Future<List<PublicProfile>> getAll({int limit = 200}) async {
    final snap = await _users.orderBy('displayName').limit(limit).get();
    final list = snap.docs.map((d) => PublicProfile.fromFirestore(d.id, d.data())).toList();
    for (final p in list) {
      _cache[p.id] = p;
    }
    return list;
  }

  void clearCache() => _cache.clear();
}
