import 'package:flutter/material.dart';

enum SessionFormat { online, inPerson }

class Seance {
  const Seance({
    required this.id,
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
  });

  final String id;
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

  bool get isOnline => format == SessionFormat.online;

  String get priceText => free ? 'Gratuit' : (priceLabel ?? '');

  Seance copyWith({
    int? seatsLeft,
    bool? reserved,
  }) {
    return Seance(
      id: id,
      subject: subject,
      title: title,
      host: host,
      date: date,
      start: start,
      end: end,
      format: format,
      place: place,
      seatsLeft: seatsLeft ?? this.seatsLeft,
      reserved: reserved ?? this.reserved,
      free: free,
      priceLabel: priceLabel,
    );
  }
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
