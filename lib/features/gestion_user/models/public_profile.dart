import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'user.dart';

/// Profil public d'un utilisateur StudyMate (l'e-mail n'est volontairement
/// pas publié : seuls le nom, le rôle et la photo sont partagés), partagé entre appareils via
/// Firestore (`users/{uid}`).
///
/// - [AppUser] reste le profil complet et privé (téléphone, justificatif…)
///   stocké localement en SQLite par le module Gestion des utilisateurs.
/// - [PublicProfile] n'en expose que ce dont les autres membres ont besoin
///   (nom, rôle, photo) et est identifié par l'UID Firebase.
class PublicProfile {
  /// UID Firebase Authentication.
  final String id;
  final String name;
  final String email;

  /// Libellé affiché (« Étudiant », « Enseignant »).
  final String role;

  /// Rôle technique du module utilisateurs : `student` | `teacher`.
  final String roleKey;

  /// URL publique de la photo (ImgBB) ; `null` = initiales.
  final String? photoUrl;

  final int avatarColorIndex;

  const PublicProfile({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'Étudiant',
    this.roleKey = 'student',
    this.photoUrl,
    this.avatarColorIndex = 0,
  });

  bool get isTeacher => roleKey == 'teacher';

  static String roleLabel(String roleKey) =>
      roleKey == 'teacher' ? 'Enseignant' : 'Étudiant';

  /// Couleur d'avatar stable dérivée de l'UID.
  static int colorIndexFor(String uid) {
    var hash = 0;
    for (final unit in uid.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash % AppColors.avatarColors.length;
  }

  /// Profil public construit à partir du profil local et de l'UID Firebase.
  factory PublicProfile.fromAppUser(String uid, AppUser user, {String? photoUrl}) {
    final name = '${user.prenom} ${user.nom}'.trim();
    return PublicProfile(
      id: uid,
      name: name.isEmpty ? 'Utilisateur' : name,
      email: user.email,
      role: roleLabel(user.role),
      roleKey: user.role,
      photoUrl: photoUrl,
      avatarColorIndex: colorIndexFor(uid),
    );
  }

  factory PublicProfile.fromFirestore(String id, Map<String, dynamic> data) {
    final roleKey = data['role'] as String? ?? 'student';
    final email = data['email'] as String? ?? '';
    final name = (data['displayName'] as String? ?? '').trim();
    final photo = (data['photoUrl'] as String? ?? '').trim();
    return PublicProfile(
      id: id,
      name: name.isEmpty ? (email.isEmpty ? 'Utilisateur' : email) : name,
      email: email,
      role: roleLabel(roleKey),
      roleKey: roleKey,
      photoUrl: photo.isEmpty ? null : photo,
      avatarColorIndex: colorIndexFor(id),
    );
  }

  /// Profil minimal quand le document Firestore est introuvable.
  factory PublicProfile.unknown(String id) => PublicProfile(
        id: id,
        name: 'Utilisateur inconnu',
        email: '',
        avatarColorIndex: colorIndexFor(id),
      );

  Map<String, Object?> toFirestore() => {
        'displayName': name,
        'role': roleKey,
        'photoUrl': photoUrl,
      };

  /// Initiales du nom (ex. « Sarah Ben Ali » -> « SA »).
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Color get avatarColor =>
      AppColors.avatarColors[avatarColorIndex % AppColors.avatarColors.length];

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PublicProfile && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
