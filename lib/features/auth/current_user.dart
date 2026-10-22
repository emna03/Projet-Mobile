import 'package:flutter/material.dart';

/// Demo identity used until real login exists.
class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.initials,
  });

  final String id;
  final String displayName;
  final String initials;

  bool owns(String ownerId) => ownerId == id;
}

const demoUsers = <AppUser>[
  AppUser(id: 'user-ab', displayName: 'Alex Benali', initials: 'AB'),
  AppUser(id: 'user-sarah', displayName: 'Sarah Ben Ali', initials: 'SB'),
  AppUser(id: 'user-yassine', displayName: 'Yassine Trabelsi', initials: 'YT'),
  AppUser(id: 'user-amine', displayName: 'Amine Khaled', initials: 'AK'),
  AppUser(id: 'user-ines', displayName: 'Ines Gharbi', initials: 'IG'),
];

/// The account currently signed in. Switch it from the avatar to test access.
class AuthSession extends ChangeNotifier {
  AuthSession._();

  static final instance = AuthSession._();

  AppUser _user = demoUsers.first;

  AppUser get user => _user;

  void signIn(AppUser user) {
    if (_user.id == user.id) return;
    _user = user;
    notifyListeners();
  }
}
