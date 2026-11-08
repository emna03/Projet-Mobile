import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../features/gestion_user/repositories/user_repository.dart';

class SessionUser {
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
}
