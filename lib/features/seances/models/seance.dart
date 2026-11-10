import 'package:flutter/material.dart';

enum SessionFormat { online, inPerson }

class Seance {
  const Seance({
    required this.id,
    required this.ownerId,
    required this.subject,
    required this.title,
    required this.host,
    required this.date,
    required this.start,
    required this.end,
    required this.format,
    required this.place,
    required this.seatsLeft,
    this.reserved = false,
    this.free = true,
    this.priceLabel,
    this.meetSpaceName,
    this.meetCode,
    this.meetAccess,
    this.calendarEventId,
  });

  final String id;
  final String ownerId;
  final String subject;
  final String title;
  final String host;
  final DateTime date;
  final TimeOfDay start;
  final TimeOfDay end;
  final SessionFormat format;
  final String place;
  final int seatsLeft;
  final bool reserved;
  final bool free;
  final String? priceLabel;
  final String? meetSpaceName;
  final String? meetCode;
  final String? meetAccess;

  /// Identifiant de l'événement dans Google Agenda, si la séance y est.
  final String? calendarEventId;

  bool get isOnline => format == SessionFormat.online;

  bool get inCalendar => calendarEventId != null && calendarEventId!.isNotEmpty;

  String get priceText => free ? 'Gratuit' : (priceLabel ?? '');

  Seance copyWith({
    String? ownerId,
    String? subject,
    String? title,
    String? host,
    DateTime? date,
    TimeOfDay? start,
    TimeOfDay? end,
    SessionFormat? format,
    String? place,
    int? seatsLeft,
    bool? reserved,
    bool? free,
    String? priceLabel,
    String? meetSpaceName,
    String? meetCode,
    String? meetAccess,
    String? calendarEventId,
    bool clearCalendarEvent = false,
  }) {
    return Seance(
      id: id,
      ownerId: ownerId ?? this.ownerId,
      subject: subject ?? this.subject,
      title: title ?? this.title,
      host: host ?? this.host,
      date: date ?? this.date,
      start: start ?? this.start,
      end: end ?? this.end,
      format: format ?? this.format,
      place: place ?? this.place,
      seatsLeft: seatsLeft ?? this.seatsLeft,
      reserved: reserved ?? this.reserved,
      free: free ?? this.free,
      priceLabel: priceLabel ?? this.priceLabel,
      meetSpaceName: meetSpaceName ?? this.meetSpaceName,
      meetCode: meetCode ?? this.meetCode,
      meetAccess: meetAccess ?? this.meetAccess,
      calendarEventId: clearCalendarEvent
          ? null
          : (calendarEventId ?? this.calendarEventId),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'subject': subject,
      'title': title,
      'host': host,
      'date': _formatDate(date),
      'start_minutes': start.hour * 60 + start.minute,
      'end_minutes': end.hour * 60 + end.minute,
      'format': format.name,
      'place': place,
      'seats_left': seatsLeft,
      'reserved': reserved ? 1 : 0,
      'free': free ? 1 : 0,
      'price_label': priceLabel,
      'meet_space_name': meetSpaceName,
      'meet_code': meetCode,
      'meet_access': meetAccess,
      'calendar_event_id': calendarEventId,
    };
  }

  factory Seance.fromMap(Map<String, Object?> map) {
    return Seance(
      id: map['id']! as String,
      ownerId: (map['owner_id'] as String?) ?? '',
      subject: map['subject']! as String,
      title: map['title']! as String,
      host: map['host']! as String,
      date: _parseDate(map['date']! as String),
      start: _timeFromMinutes(map['start_minutes']! as int),
      end: _timeFromMinutes(map['end_minutes']! as int),
      format: SessionFormat.values.byName(map['format']! as String),
      place: map['place']! as String,
      seatsLeft: map['seats_left']! as int,
      reserved: (map['reserved']! as int) == 1,
      free: (map['free']! as int) == 1,
      priceLabel: map['price_label'] as String?,
      meetSpaceName: map['meet_space_name'] as String?,
      meetCode: map['meet_code'] as String?,
      meetAccess: map['meet_access'] as String?,
      calendarEventId: map['calendar_event_id'] as String?,
    );
  }
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime _parseDate(String value) {
  final parts = value.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

TimeOfDay _timeFromMinutes(int minutes) {
  return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}

String formatSeanceDay(DateTime date) {
  const days = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
  const months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
}

String formatSeanceTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
