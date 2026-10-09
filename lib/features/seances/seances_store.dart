import 'package:flutter/material.dart';
import 'package:studymate/features/seances/models/seance.dart';

/// In-memory list for the séances de révision screen.
/// Other modules can later replace this with a shared backend.
class SeancesStore extends ChangeNotifier {
  SeancesStore() : _items = List<Seance>.of(_samples);

  final List<Seance> _items;
  SessionFormat? _format;

  SessionFormat? get format => _format;

  List<Seance> get items {
    final selected = _format;
    if (selected == null) return List.unmodifiable(_items);
    return List.unmodifiable(
      _items.where((seance) => seance.format == selected),
    );
  }

  void setFormat(SessionFormat? format) {
    if (_format == format) return;
    _format = format;
    notifyListeners();
  }

  void toggleReservation(String id) {
    final index = _items.indexWhere((seance) => seance.id == id);
    if (index == -1) return;
    final current = _items[index];
    if (current.reserved) {
      _items[index] = current.copyWith(
        reserved: false,
        seatsLeft: current.seatsLeft + 1,
      );
    } else if (current.seatsLeft > 0) {
      _items[index] = current.copyWith(
        reserved: true,
        seatsLeft: current.seatsLeft - 1,
      );
    }
    notifyListeners();
  }

  void add(Seance seance) {
    _items.insert(0, seance);
    notifyListeners();
  }
}

final _samples = <Seance>[
  Seance(
    id: 'docker',
    subject: 'Docker',
    title: 'Docker, de zéro à déployé',
    host: 'Yassine Trabelsi',
    date: DateTime(2026, 10, 7),
    start: TimeOfDay(hour: 18, minute: 0),
    end: TimeOfDay(hour: 19, minute: 30),
    format: SessionFormat.online,
    place: 'Visioconférence',
    seatsLeft: 4,
    reserved: true,
  ),
  Seance(
    id: 'spring',
    subject: 'Spring Boot',
    title: 'Construire une API Spring Boot',
    host: 'Sarah Ben Ali',
    date: DateTime(2026, 10, 8),
    start: TimeOfDay(hour: 14, minute: 0),
    end: TimeOfDay(hour: 16, minute: 0),
    format: SessionFormat.inPerson,
    place: 'Salle B12',
    seatsLeft: 3,
  ),
  Seance(
    id: 'git',
    subject: 'Git',
    title: 'Git & GitHub sans stress',
    host: 'Amine Khaled',
    date: DateTime(2026, 10, 9),
    start: TimeOfDay(hour: 10, minute: 0),
    end: TimeOfDay(hour: 11, minute: 30),
    format: SessionFormat.online,
    place: 'Visioconférence',
    seatsLeft: 8,
  ),
  Seance(
    id: 'uml',
    subject: 'UML',
    title: 'Modéliser un projet avec UML',
    host: 'Ines Gharbi',
    date: DateTime(2026, 10, 10),
    start: TimeOfDay(hour: 9, minute: 0),
    end: TimeOfDay(hour: 12, minute: 0),
    format: SessionFormat.inPerson,
    place: 'Salle A3',
    seatsLeft: 2,
  ),
];
