import 'package:studymate/features/availability/availability_models.dart';
import 'package:studymate/features/calendar/calendar_event.dart';
import 'package:studymate/features/calendar/google_calendar_api.dart';
import 'package:studymate/features/seances/models/seance.dart';

/// Deux périodes se chevauchent si elles partagent du temps. Deux périodes
/// qui se touchent (l'une finit quand l'autre commence) ne se chevauchent pas.
bool intervalsOverlap(
  DateTime aStart,
  DateTime aEnd,
  DateTime bStart,
  DateTime bEnd,
) => aStart.isBefore(bEnd) && bStart.isBefore(aEnd);

/// Séances de [others] dont l'horaire chevauche celui de [candidate], de la
/// plus proche à la plus lointaine. [candidate] elle-même est ignorée.
List<Seance> conflictingSeances(Seance candidate, Iterable<Seance> others) {
  final mine = seanceInterval(candidate);
  final conflicts = <Seance>[];
  for (final other in others) {
    if (other.id == candidate.id) continue;
    final theirs = seanceInterval(other);
    if (intervalsOverlap(mine.start, mine.end, theirs.start, theirs.end)) {
      conflicts.add(other);
    }
  }
  conflicts.sort(
    (a, b) => seanceInterval(a).start.compareTo(seanceInterval(b).start),
  );
  return conflicts;
}

/// Conflits entre les séances de [mine] qui ne sont pas encore terminées à
/// [now] : pour chaque séance en conflit, les séances qu'elle chevauche.
Map<String, List<Seance>> detectSeanceConflicts(
  Iterable<Seance> mine, {
  required DateTime now,
}) {
  final upcoming = [
    for (final seance in mine)
      if (seanceInterval(seance).end.isAfter(now)) seance,
  ];
  final conflicts = <String, List<Seance>>{};
  for (final seance in upcoming) {
    final others = conflictingSeances(seance, upcoming);
    if (others.isNotEmpty) conflicts[seance.id] = others;
  }
  return conflicts;
}

/// Participants de [participants] qui ne sont pas libres pendant [seance].
///
/// Un participant qui n'a saisi aucune plage est ignoré : on ne sait rien de
/// ses disponibilités, ce n'est pas un conflit. Une séance qui passe minuit
/// ne tient dans aucune plage, puisqu'une plage reste dans une même journée.
List<Participant> unavailableParticipants(
  Seance seance,
  Iterable<Participant> participants,
) {
  final interval = seanceInterval(seance);
  final start = interval.start;
  final startMinutes = start.hour * 60 + start.minute;
  final endMinutes = startMinutes + interval.end.difference(start).inMinutes;
  return [
    for (final participant in participants)
      if (participant.windows.isNotEmpty &&
          !participant.windows.any(
            (window) =>
                window.weekday == start.weekday &&
                window.covers(startMinutes, endMinutes),
          ))
        participant,
  ];
}

/// Événements Google Agenda qui chevauchent [seance]. Les événements sur la
/// journée entière et l'événement créé par cette séance sont ignorés.
List<CalendarEvent> conflictingEvents(
  Seance seance,
  Iterable<CalendarEvent> events,
) {
  final interval = seanceInterval(seance);
  return [
    for (final event in events)
      if (!event.allDay &&
          event.seanceId != seance.id &&
          event.id != seance.calendarEventId &&
          intervalsOverlap(interval.start, interval.end, event.start, event.end))
        event,
  ];
}

/// « Titre (18:00 – 19:30) », pour nommer une séance en conflit.
String describeSeanceSlot(Seance seance) =>
    '« ${seance.title} » (${formatSeanceTime(seance.start)} – '
    '${formatSeanceTime(seance.end)})';
