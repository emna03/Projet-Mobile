/// Niveaux de maîtrise déterministes (calcul local, pas inventés par l’IA).
enum MasteryLevel {
  unevalue,
  faible,
  moyenne,
  bonne,
  excellente,
}

extension MasteryLevelLabel on MasteryLevel {
  String get label => switch (this) {
        MasteryLevel.unevalue => 'Non évalué',
        MasteryLevel.faible => 'Faible',
        MasteryLevel.moyenne => 'Moyenne',
        MasteryLevel.bonne => 'Bonne',
        MasteryLevel.excellente => 'Excellente',
      };

  String get shortId => name;
}

MasteryLevel masteryLevelFromName(String? raw) {
  final v = (raw ?? '').trim().toLowerCase();
  return MasteryLevel.values.firstWhere(
    (e) => e.name == v,
    orElse: () => MasteryLevel.unevalue,
  );
}
