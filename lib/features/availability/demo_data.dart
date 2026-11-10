import 'package:flutter/material.dart';
import 'package:studymate/features/availability/availability_models.dart';
import 'package:studymate/features/seances/models/seance.dart';

/// Les identifiants de démonstration commencent par ce préfixe : c'est ainsi
/// qu'on les retrouve pour les supprimer sans toucher aux vraies données.
const demoPrefix = 'demo-';

bool isDemoId(String id) => id.startsWith(demoPrefix);

/// Participant fictif. Ce n'est pas un compte de connexion : il n'existe que
/// dans la base locale de l'application, pour tester les créneaux communs.
class DemoUser {
  const DemoUser({
    required this.id,
    required this.name,
    required this.email,
    required this.windows,
  });

  final String id;
  final String name;
  final String email;
  final List<AvailabilityWindow> windows;
}

AvailabilityWindow _window(
  int weekday,
  int fromHour,
  int fromMinute,
  int toHour,
  int toMinute,
) {
  return AvailabilityWindow(
    weekday: weekday,
    startMinutes: fromHour * 60 + fromMinute,
    endMinutes: toHour * 60 + toMinute,
  );
}

/// Disponibilités de l'utilisateur connecté quand il n'en a pas encore :
/// du lundi au vendredi en soirée, et le samedi matin.
final List<AvailabilityWindow> demoOwnerWindows = [
  for (final day in [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  ])
    _window(day, 17, 0, 21, 0),
  _window(DateTime.saturday, 9, 0, 13, 0),
];

final DemoUser demoSarah = DemoUser(
  id: '${demoPrefix}sarah',
  name: 'Sarah Ben Ali',
  email: 'sarah.benali@studymate.test',
  windows: [
    _window(DateTime.monday, 16, 0, 20, 0),
    _window(DateTime.wednesday, 16, 0, 20, 0),
    _window(DateTime.friday, 16, 0, 20, 0),
    _window(DateTime.saturday, 10, 0, 14, 0),
  ],
);

final DemoUser demoYassine = DemoUser(
  id: '${demoPrefix}yassine',
  name: 'Yassine Trabelsi',
  email: 'yassine.trabelsi@studymate.test',
  windows: [
    _window(DateTime.tuesday, 18, 0, 22, 0),
    _window(DateTime.wednesday, 18, 0, 22, 0),
    _window(DateTime.thursday, 18, 0, 22, 0),
    _window(DateTime.saturday, 9, 0, 12, 0),
  ],
);

final DemoUser demoInes = DemoUser(
  id: '${demoPrefix}ines',
  name: 'Ines Gharbi',
  email: 'ines.gharbi@studymate.test',
  windows: [
    _window(DateTime.monday, 17, 0, 19, 30),
    _window(DateTime.wednesday, 17, 0, 19, 30),
    _window(DateTime.saturday, 11, 0, 15, 0),
  ],
);

final DemoUser demoAmine = DemoUser(
  id: '${demoPrefix}amine',
  name: 'Amine Khaled',
  email: 'amine.khaled@studymate.test',
  windows: [
    _window(DateTime.wednesday, 18, 0, 21, 0),
    _window(DateTime.thursday, 17, 0, 19, 0),
    _window(DateTime.saturday, 10, 0, 12, 30),
  ],
);

/// Séances d'exemple et leurs participants.
class DemoData {
  const DemoData({required this.seances, required this.participants});

  final List<Seance> seances;

  /// Participants de chaque séance, par identifiant de séance.
  final Map<String, List<DemoUser>> participants;

  /// Chaque participant fictif une seule fois.
  List<DemoUser> get users {
    final byId = <String, DemoUser>{};
    for (final list in participants.values) {
      for (final user in list) {
        byId[user.id] = user;
      }
    }
    return byId.values.toList();
  }
}

/// Quatre séances qui commencent dans 2 à 5 jours, à une heure qui ne convient
/// volontairement pas à tout le monde : la page « Créneaux communs » doit
/// proposer mieux. Elles appartiennent à [ownerId], qui peut donc les modifier.
///
/// Avec les disponibilités ci-dessus :
/// - Algorithmique (1 h 30) : un seul créneau commun, le mercredi 18:00.
/// - SQL (2 h) : le mercredi 18:00 et le samedi à partir de 10:00 (avec marge).
/// - Réseaux (1 h) : le mercredi 18:00 (marge 30 min) et le samedi 11:00.
/// - Flutter (2 h) : aucun créneau commun, seulement des compromis.
///
/// Une cinquième séance, « Point projet intégré », chevauche exprès
/// Algorithmique (même jour, 20:30 – 21:30) pour montrer un conflit
/// d'horaire. Elle n'a pas de participants.
DemoData buildDemoData({
  required DateTime now,
  required String ownerId,
  required String ownerName,
}) {
  DateTime inDays(int days) => DateTime(now.year, now.month, now.day + days);

  Seance seance({
    required String suffix,
    required String subject,
    required String title,
    required int days,
    required TimeOfDay start,
    required TimeOfDay end,
    required SessionFormat format,
    required String place,
  }) {
    return Seance(
      id: '$demoPrefix$suffix',
      ownerId: ownerId,
      subject: subject,
      title: title,
      host: ownerName,
      date: inDays(days),
      start: start,
      end: end,
      format: format,
      place: place,
      seatsLeft: 8,
    );
  }

  final algo = seance(
    suffix: 'algo',
    subject: 'Algorithmique',
    title: 'Révisions Algorithmique',
    days: 2,
    start: const TimeOfDay(hour: 20, minute: 0),
    end: const TimeOfDay(hour: 21, minute: 30),
    format: SessionFormat.inPerson,
    place: 'Salle B12',
  );
  final sql = seance(
    suffix: 'sql',
    subject: 'Bases de données',
    title: 'Atelier SQL & bases de données',
    days: 3,
    start: const TimeOfDay(hour: 8, minute: 0),
    end: const TimeOfDay(hour: 10, minute: 0),
    format: SessionFormat.online,
    place: 'Google Meet (lien à créer)',
  );
  final reseaux = seance(
    suffix: 'reseaux',
    subject: 'Réseaux',
    title: 'Préparation examen Réseaux',
    days: 4,
    start: const TimeOfDay(hour: 21, minute: 0),
    end: const TimeOfDay(hour: 22, minute: 0),
    format: SessionFormat.inPerson,
    place: 'Bibliothèque ESPRIT',
  );
  final flutter = seance(
    suffix: 'flutter',
    subject: 'Flutter',
    title: 'Projet Flutter : revue de code',
    days: 5,
    start: const TimeOfDay(hour: 7, minute: 30),
    end: const TimeOfDay(hour: 9, minute: 30),
    format: SessionFormat.online,
    place: 'Google Meet (lien à créer)',
  );

  final conflit = seance(
    suffix: 'conflit',
    subject: 'Projet intégré',
    title: 'Point projet intégré',
    days: 2,
    start: const TimeOfDay(hour: 20, minute: 30),
    end: const TimeOfDay(hour: 21, minute: 30),
    format: SessionFormat.inPerson,
    place: 'Salle A3',
  );

  return DemoData(
    seances: [algo, sql, reseaux, flutter, conflit],
    participants: {
      algo.id: [demoSarah, demoYassine, demoInes],
      sql.id: [demoSarah, demoAmine],
      reseaux.id: [demoYassine, demoAmine, demoInes],
      flutter.id: [demoSarah, demoYassine, demoInes, demoAmine],
    },
  );
}
