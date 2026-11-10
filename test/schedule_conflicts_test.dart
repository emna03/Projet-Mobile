import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/availability/availability_models.dart';
import 'package:studymate/features/calendar/calendar_event.dart';
import 'package:studymate/features/conflicts/schedule_conflicts.dart';
import 'package:studymate/features/seances/models/seance.dart';

/// Mardi 10 novembre 2026, 09:00.
final _now = DateTime(2026, 11, 10, 9);

Seance _seance(
  String id, {
  int day = 12,
  int fromHour = 18,
  int fromMinute = 0,
  int toHour = 19,
  int toMinute = 30,
  String? calendarEventId,
}) {
  return Seance(
    id: id,
    ownerId: 'user-ab',
    subject: 'Matière',
    title: 'Séance $id',
    host: 'Alex Benali',
    date: DateTime(2026, 11, day),
    start: TimeOfDay(hour: fromHour, minute: fromMinute),
    end: TimeOfDay(hour: toHour, minute: toMinute),
    format: SessionFormat.inPerson,
    place: 'Salle B12',
    seatsLeft: 5,
    calendarEventId: calendarEventId,
  );
}

AvailabilityWindow _w(int day, int fromHour, int toHour) => AvailabilityWindow(
  weekday: day,
  startMinutes: fromHour * 60,
  endMinutes: toHour * 60,
);

CalendarEvent _event(
  String id,
  DateTime start,
  DateTime end, {
  bool allDay = false,
  String? seanceId,
}) {
  return CalendarEvent(
    id: id,
    title: 'Événement $id',
    start: start,
    end: end,
    allDay: allDay,
    seanceId: seanceId,
  );
}

void main() {
  group('conflictingSeances', () {
    test('finds seances that share time, nearest first', () {
      final a = _seance('a');
      final conflicts = conflictingSeances(a, [
        _seance('late', fromHour: 19, toHour: 20, toMinute: 0),
        _seance('early', fromHour: 17, toHour: 18, toMinute: 30),
        _seance('other-day', day: 13),
        a,
      ]);

      expect(conflicts.map((s) => s.id), ['early', 'late']);
    });

    test('seances that only touch do not conflict', () {
      final a = _seance('a');
      final conflicts = conflictingSeances(a, [
        _seance('before', fromHour: 16, toHour: 18, toMinute: 0),
        _seance('after', fromHour: 19, fromMinute: 30, toHour: 21, toMinute: 0),
      ]);

      expect(conflicts, isEmpty);
    });

    test('a seance inside another one conflicts', () {
      final long = _seance('long', fromHour: 14, toHour: 20, toMinute: 0);
      final short = _seance('short', fromHour: 16, toHour: 17, toMinute: 0);

      expect(conflictingSeances(long, [short]).single.id, 'short');
      expect(conflictingSeances(short, [long]).single.id, 'long');
    });

    test('a seance that passes midnight conflicts with the next morning', () {
      final night = _seance('night', fromHour: 23, toHour: 1, toMinute: 0);
      final nextMorning = _seance(
        'morning',
        day: 13,
        fromHour: 0,
        fromMinute: 30,
        toHour: 2,
        toMinute: 0,
      );

      expect(conflictingSeances(night, [nextMorning]).single.id, 'morning');
    });
  });

  group('detectSeanceConflicts', () {
    test('maps every conflicting seance to the ones it overlaps', () {
      final conflicts = detectSeanceConflicts([
        _seance('a'),
        _seance('b', fromHour: 19, toHour: 20, toMinute: 0),
        _seance('c', day: 14),
      ], now: _now);

      expect(conflicts.keys.toSet(), {'a', 'b'});
      expect(conflicts['a']!.single.id, 'b');
      expect(conflicts['b']!.single.id, 'a');
    });

    test('ignores seances that are already over', () {
      final conflicts = detectSeanceConflicts([
        _seance('past-a', day: 9),
        _seance('past-b', day: 9, fromHour: 19, toHour: 20, toMinute: 0),
      ], now: _now);

      expect(conflicts, isEmpty);
    });

    test('keeps a seance that is still running', () {
      final conflicts = detectSeanceConflicts([
        _seance('running', day: 10, fromHour: 8, toHour: 10, toMinute: 0),
        _seance('next', day: 10, fromHour: 9, fromMinute: 30, toHour: 11, toMinute: 0),
      ], now: _now);

      expect(conflicts.keys.toSet(), {'running', 'next'});
    });

    test('no conflict means an empty map', () {
      expect(
        detectSeanceConflicts([_seance('a'), _seance('b', day: 13)], now: _now),
        isEmpty,
      );
    });
  });

  group('unavailableParticipants', () {
    // Le 12 novembre 2026 est un jeudi.
    final seance = _seance('a');

    test('lists participants whose windows do not cover the seance', () {
      final people = [
        Participant(
          id: 'free',
          name: 'Libre',
          windows: [_w(DateTime.thursday, 17, 21)],
        ),
        Participant(
          id: 'short',
          name: 'Trop court',
          windows: [_w(DateTime.thursday, 18, 19)],
        ),
        Participant(
          id: 'wrong-day',
          name: 'Autre jour',
          windows: [_w(DateTime.wednesday, 17, 21)],
        ),
      ];

      expect(unavailableParticipants(seance, people).map((p) => p.id), [
        'short',
        'wrong-day',
      ]);
    });

    test('ignores a participant who gave no availability', () {
      const unknown = Participant(id: 'unknown', name: 'Inconnu');

      expect(unavailableParticipants(seance, [unknown]), isEmpty);
    });

    test('a window that exactly fits the seance is enough', () {
      final exact = Participant(
        id: 'exact',
        name: 'Juste',
        windows: [
          const AvailabilityWindow(
            weekday: DateTime.thursday,
            startMinutes: 18 * 60,
            endMinutes: 19 * 60 + 30,
          ),
        ],
      );

      expect(unavailableParticipants(seance, [exact]), isEmpty);
    });

    test('nobody is free for a seance that passes midnight', () {
      final night = _seance('night', fromHour: 23, toHour: 1, toMinute: 0);
      final owl = Participant(
        id: 'owl',
        name: 'Couche-tard',
        windows: [_w(DateTime.thursday, 20, 24)],
      );

      expect(unavailableParticipants(night, [owl]).single.id, 'owl');
    });
  });

  group('conflictingEvents', () {
    final seance = _seance('a', calendarEventId: 'own-event');

    test('finds timed events that overlap the seance', () {
      final events = [
        _event('overlap', DateTime(2026, 11, 12, 19), DateTime(2026, 11, 12, 20)),
        _event('touch', DateTime(2026, 11, 12, 19, 30), DateTime(2026, 11, 12, 21)),
        _event('other-day', DateTime(2026, 11, 13, 18), DateTime(2026, 11, 13, 19)),
      ];

      expect(conflictingEvents(seance, events).map((e) => e.id), ['overlap']);
    });

    test('ignores all-day events and the event of the seance itself', () {
      final events = [
        _event(
          'all-day',
          DateTime(2026, 11, 12),
          DateTime(2026, 11, 13),
          allDay: true,
        ),
        _event('own-event', DateTime(2026, 11, 12, 18), DateTime(2026, 11, 12, 19, 30)),
        _event(
          'lost-id',
          DateTime(2026, 11, 12, 18),
          DateTime(2026, 11, 12, 19, 30),
          seanceId: 'a',
        ),
      ];

      expect(conflictingEvents(seance, events), isEmpty);
    });
  });

  test('describes a seance slot', () {
    expect(describeSeanceSlot(_seance('a')), '« Séance a » (18:00 – 19:30)');
  });
}
