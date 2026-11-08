import 'package:firebase_auth/firebase_auth.dart';

import '../../features/groups/repositories/firestore_group_repository.dart';
import '../../features/groups/viewmodels/group_viewmodel.dart';
import '../widgets/resource_scope.dart';

/// ViewModel des groupes partagé par toute l'application (onglet Groupes,
/// détail d'un groupe, sélecteur « réservée à un groupe » des ressources).
///
/// Il suit la session Firebase : à chaque connexion / déconnexion, l'état est
/// réinitialisé et rechargé pour le nouvel utilisateur.
late final GroupViewModel groupViewModel;

bool _initialized = false;

/// À appeler une fois, après `Firebase.initializeApp`.
void initAppServices() {
  if (_initialized) return;
  _initialized = true;
  groupViewModel = GroupViewModel(
    repository: FirestoreGroupRepository(),
    sessionChanges: FirebaseAuth.instance.authStateChanges(),
  );
  // Module Ressources ↔ module Groupes : appartenance aux groupes pour la
  // visibilité « réservée à un groupe ».
  resourceViewModel.attachGroups(groupViewModel);
}
