import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:studymate/features/gestion_user/repositories/user_repository.dart';

/// The signed-in account, as seen by the séances feature.
class SeanceUser {
  const SeanceUser({
    required this.id,
    required this.displayName,
    required this.initials,
  });

  static const anonymous = SeanceUser(id: '', displayName: '', initials: '?');

  final String id;
  final String displayName;
  final String initials;

  bool owns(String ownerId) => id.isNotEmpty && ownerId == id;
}

/// Builds the séances identity from Firebase Auth and the local profile.
Future<SeanceUser> loadCurrentSeanceUser() async {
  final account = FirebaseAuth.instance.currentUser;
  if (account == null) return SeanceUser.anonymous;

  final email = account.email ?? '';
  var name = '';
  try {
    final profile = await UserRepository().getUserByEmail(email);
    if (profile != null) name = '${profile.prenom} ${profile.nom}'.trim();
  } catch (error) {
    debugPrint('Seance profile lookup error: $error');
  }
  if (name.isEmpty) name = account.displayName?.trim() ?? '';
  if (name.isEmpty) name = email.isEmpty ? 'Utilisateur' : email;

  return SeanceUser(
    id: account.uid,
    displayName: name,
    initials: _initialsOf(name),
  );
}

String _initialsOf(String name) {
  final letters = name
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word[0].toUpperCase())
      .join();
  return letters.isEmpty ? '?' : letters;
}
