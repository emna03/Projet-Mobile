import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/gestion_user/repositories/profile_directory.dart';
import '../../features/gestion_user/repositories/user_repository.dart';
import '../config/imgbb_config.dart';
import '../services/imgbb_service.dart';

/// Session de l'utilisateur connecté, partagée par TOUS les modules
/// (utilisateurs, ressources, groupes, chat).
///
/// Firebase Authentication est la seule source d'identité : l'UID Firebase
/// identifie les propriétaires et membres des groupes, les auteurs des
/// messages, des votes et des réactions.
class SessionUser {
  SessionUser._();

  /// UID Firebase de l'utilisateur connecté ('' si déconnecté).
  static String get uid {
    if (Firebase.apps.isEmpty) return '';
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  static String get email {
    if (Firebase.apps.isEmpty) return '';
    final user = FirebaseAuth.instance.currentUser;
    return (user?.email ?? '').trim().toLowerCase();
  }

  static String get displayName {
    if (Firebase.apps.isEmpty) return '';
    final user = FirebaseAuth.instance.currentUser;
    final display = (user?.displayName ?? '').trim();
    if (display.isNotEmpty) return display;
    return email.isEmpty ? 'Invité' : email;
  }

  static bool get isSignedIn => email.isNotEmpty;

  /// 'student' | 'teacher' | '' (non résolu). lu dans la table SQLite `users`.
  static String role = '';

  static bool get isTeacher => role == 'teacher';

  static Future<void> refreshRole() async {
    final mail = email;
    if (mail.isEmpty) return;
    try {
      final user = await UserRepository().getUserByEmail(mail);
      role = user?.role ?? '';
    } catch (e) {
      debugPrint('SessionUser.refreshRole: $e');
    }
  }

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static String _photoKey(String uid) => 'published_photo_$uid';

  /// Publie le profil public (nom, rôle, photo) de l'utilisateur connecté
  /// dans Firestore pour que les autres membres le voient.
  ///
  /// Ne bloque jamais la connexion : les erreurs (réseau, règles) sont
  /// journalisées. La photo locale n'est envoyée sur ImgBB que si elle a
  /// changé depuis la dernière publication.
  static Future<void> syncProfile() async {
    final id = uid;
    final mail = email;
    if (id.isEmpty || mail.isEmpty) return;
    try {
      final user = await UserRepository().getUserByEmail(mail);
      if (user == null) return;
      role = user.role;

      String? photoUrl;
      var clearPhoto = false;
      final local = (user.photoPath ?? '').trim();
      if (local.startsWith('http')) {
        photoUrl = local;
      } else if (local.isEmpty) {
        clearPhoto = await _readPublished(id) != null;
      } else if (!kIsWeb && await _readPublished(id) != local) {
        try {
          photoUrl = await ImgBBService(apiKey: ImgBBConfig.apiKey).uploadImage(local);
        } catch (e) {
          debugPrint('SessionUser.syncProfile (photo): $e');
        }
      }

      await ProfileDirectory.instance.publish(uid: id, user: user, photoUrl: photoUrl);
      if (clearPhoto) {
        await ProfileDirectory.instance.clearPhoto(id);
        await _writePublished(id, null);
      } else if (photoUrl != null) {
        await _writePublished(id, local);
      }
    } catch (e) {
      debugPrint('SessionUser.syncProfile: $e');
    }
  }

  static Future<String?> _readPublished(String id) async {
    try {
      return await _storage.read(key: _photoKey(id));
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writePublished(String id, String? value) async {
    try {
      if (value == null) {
        await _storage.delete(key: _photoKey(id));
      } else {
        await _storage.write(key: _photoKey(id), value: value);
      }
    } catch (_) {}
  }
}
