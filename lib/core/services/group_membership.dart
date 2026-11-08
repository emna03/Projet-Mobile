import 'package:flutter/foundation.dart';

/// Résumé minimal d'un groupe, utilisé par les modules qui doivent connaître
/// les groupes de l'utilisateur sans dépendre du module Groupes
/// (ex. sélecteur « réservée à un groupe » des ressources).
class GroupRef {
  final String id;
  final String name;
  const GroupRef(this.id, this.name);
}

/// Contrat exposé par le module Groupes aux autres modules.
///
/// Implémenté par `GroupViewModel` ; consommé par `ResourceViewModel` pour
/// filtrer les ressources « réservées à un groupe ».
abstract class GroupMembershipSource implements Listenable {
  /// Groupes dont l'utilisateur connecté est membre (propriétaire inclus).
  List<GroupRef> get memberGroups;

  /// Identifiants (Firestore) des groupes de l'utilisateur connecté.
  Set<String> get memberGroupIds;
}
