import '../../../features/users/models/user.dart';

/// Centralised mock authentication session for local development.
///
/// Replace [_current] with the result of a real auth flow when you integrate
/// a backend (Firebase Auth, JWT, etc.).  All repository / ViewModel code
/// must reference [AppSession.currentUser] instead of hardcoding a user ID.
class AppSession {
  AppSession._();

  /// The currently authenticated user.
  ///
  /// This matches the seed user `u0` inserted in [DatabaseMigrations].
  static const User currentUser = User(
    id: 'u0',
    name: 'Ilyes Étudiant',
    email: 'ilyes@studymate.tn',
    role: 'Étudiant',
    avatarColorIndex: 0,
  );

  static String get currentUserId => currentUser.id;
}
