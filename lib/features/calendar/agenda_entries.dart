import 'package:studymate/features/calendar/calendar_event.dart';
import 'package:studymate/features/calendar/google_calendar_api.dart';
import 'package:studymate/features/seances/models/seance.dart';

/// Une ligne de la page « Mon agenda » : un événement Google, ou une séance
/// de révision que l'utilisateur a réservée.
class AgendaEntry {
  const AgendaEntry.google(CalendarEvent event) : seance = null, _event = event;

  const AgendaEntry.seance(Seance this.seance) : _event = null;

  final Seance? seance;
  final CalendarEvent? _event;

  bool get isSeance => seance != null;

  /// Événement Google lié : celui de l'agenda, ou null pour une séance qui
  /// n'y a pas été ajoutée.
  CalendarEvent? get event => _event;

  String get label => seance?.title ?? _event!.title;
  DateTime get start =>
      seance != null ? seanceInterval(seance!).start : _event!.start;
  DateTime get end => seance != null ? seanceInterval(seance!).end : _event!.end;
  bool get allDay => _event?.allDay ?? false;
  String? get location {
    final place = seance?.place.trim();
    if (place != null) return place.isEmpty ? null : place;
    return _event!.location;
  }
}

/// Fusionne [events] et les séances [reserved] qui commencent entre [from]
/// (inclus) et [to] (exclu), triés par début.
///
/// Une séance réservée qui est aussi dans l'agenda n'apparaît qu'une fois,
/// comme séance : on la reconnaît à son identifiant d'événement mémorisé ou à
/// l'identifiant de séance que StudyMate a écrit dans l'événement.
List<AgendaEntry> buildAgenda({
  required List<CalendarEvent> events,
  required List<Seance> reserved,
  required DateTime from,
  required DateTime to,
}) {
  final shown = reserved.where((seance) {
    final start = seanceInterval(seance).start;
    return !start.isBefore(from) && start.isBefore(to);
  }).toList();

  final reservedIds = {for (final seance in reserved) seance.id};
  final reservedEventIds = {
    for (final seance in reserved)
      if (seance.inCalendar) seance.calendarEventId!,
  };

  final entries = <AgendaEntry>[
    for (final seance in shown) AgendaEntry.seance(seance),
    for (final event in events)
      if (!reservedEventIds.contains(event.id) &&
          !(event.seanceId != null && reservedIds.contains(event.seanceId)))
        AgendaEntry.google(event),
  ];

  entries.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    return a.label.compareTo(b.label);
  });
  return entries;
}

/// Regroupe [entries] (déjà triées) par jour, dans l'ordre.
List<({DateTime day, List<AgendaEntry> entries})> groupByDay(
  List<AgendaEntry> entries,
) {
  final groups = <({DateTime day, List<AgendaEntry> entries})>[];
  for (final entry in entries) {
    final day = DateTime(entry.start.year, entry.start.month, entry.start.day);
    if (groups.isNotEmpty && groups.last.day == day) {
      groups.last.entries.add(entry);
    } else {
      groups.add((day: day, entries: [entry]));
    }
  }
  return groups;
}
