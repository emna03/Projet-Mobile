/// Événement lu dans le Google Agenda de l'utilisateur.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.location,
    this.htmlLink,
    this.seanceId,
  });

  final String id;
  final String title;
  final DateTime start;

  /// Fin exclusive pour un événement sur la journée entière.
  final DateTime end;
  final bool allDay;
  final String? location;

  /// Lien qui ouvre l'événement dans Google Agenda.
  final String? htmlLink;

  /// Identifiant de la séance StudyMate à l'origine de l'événement, si c'est
  /// StudyMate qui l'a créé.
  final String? seanceId;

  bool get fromStudyMate => seanceId != null;

  /// Lit un élément de `events.list`. Renvoie null pour un événement annulé
  /// ou illisible.
  static CalendarEvent? fromJson(Map<String, Object?> json) {
    if (json['status'] == 'cancelled') return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final start = _parseWhen(json['start']);
    if (start == null) return null;
    final end = _parseWhen(json['end']);

    final summary = json['summary'];
    final title = summary is String && summary.trim().isNotEmpty
        ? summary.trim()
        : '(Sans titre)';
    final location = json['location'];
    final link = json['htmlLink'];

    String? seanceId;
    final extended = json['extendedProperties'];
    if (extended is Map) {
      final private = extended['private'];
      if (private is Map && private['studymateSeanceId'] is String) {
        seanceId = private['studymateSeanceId'] as String;
      }
    }

    return CalendarEvent(
      id: id,
      title: title,
      start: start.value,
      end: end?.value ?? start.value,
      allDay: start.allDay,
      location: location is String && location.trim().isNotEmpty
          ? location.trim()
          : null,
      htmlLink: link is String && link.isNotEmpty ? link : null,
      seanceId: seanceId,
    );
  }
}

({DateTime value, bool allDay})? _parseWhen(Object? raw) {
  if (raw is! Map) return null;
  final dateTime = raw['dateTime'];
  if (dateTime is String) {
    final parsed = DateTime.tryParse(dateTime);
    if (parsed == null) return null;
    return (value: parsed.toLocal(), allDay: false);
  }
  final date = raw['date'];
  if (date is String) {
    final parts = date.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return (value: DateTime(year, month, day), allDay: true);
  }
  return null;
}
