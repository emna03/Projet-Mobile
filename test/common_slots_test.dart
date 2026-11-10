import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/availability/availability_models.dart';
import 'package:studymate/features/availability/common_slots.dart';
import 'package:studymate/features/availability/demo_data.dart';

/// Mardi 10 novembre 2026, 09:00. Le mercredi suivant est le 11.
final _from = DateTime(2026, 11, 10, 9);

const _me = 'user-me';

Participant _owner() => Participant(
  id: _me,
  name: 'Moi',
  isMe: true,
  windows: demoOwnerWindows,
);

Participant _from_(DemoUser user) =>
    Participant(id: user.id, name: user.name, windows: user.windows);

List<Participant> _group(List<DemoUser> users) => [
  _owner(),
  for (final user in users) _from_(user),
];

String _label(SlotProposal slot) {
  final day = '${slot.start.day}/${slot.start.month}';
  final start = formatMinutes(slot.start.hour * 60 + slot.start.minute);
  final end = formatMinutes(slot.end.hour * 60 + slot.end.minute);
  final latest = formatMinutes(slot.latestStart.hour * 60 + slot.latestStart.minute);
  return '$day $start-$end${slot.isFlexible ? ' (jusqu\'à $latest)' : ''}';
}

void main() {
  group('normalizeWindows', () {
    AvailabilityWindow w(int day, int from, int to) =>
        AvailabilityWindow(weekday: day, startMinutes: from, endMinutes: to);

    test('merges overlapping and touching windows of the same day', () {
      final merged = normalizeWindows([
        w(3, 18 * 60, 20 * 60),
        w(3, 17 * 60, 19 * 60),
        w(3, 20 * 60, 21 * 60),
        w(5, 10 * 60, 12 * 60),
      ]);

      expect(merged, [w(3, 17 * 60, 21 * 60), w(5, 10 * 60, 12 * 60)]);
    });

    test('drops empty and inverted windows and keeps days apart', () {
      final merged = normalizeWindows([
        w(1, 600, 600),
        w(1, 700, 650),
        w(1, 600, 660),
        w(2, 600, 660),
      ]);

      expect(merged, [w(1, 600, 660), w(2, 600, 660)]);
    });

    test('summarizes windows by time range', () {
      expect(summarizeWindows(const []), 'Aucune disponibilité');
      expect(
        summarizeWindows([
          w(1, 16 * 60, 20 * 60),
          w(3, 16 * 60, 20 * 60),
          w(6, 10 * 60, 14 * 60),
        ]),
        'Lun., Mer. 16:00–20:00 · Sam. 10:00–14:00',
      );
    });
  });

  group('proposeSlots with the demo participants', () {
    test('Algorithmique (1 h 30): only Wednesday 18:00 suits everyone', () {
      final slots = proposeSlots(
        participants: _group([demoSarah, demoYassine, demoInes]),
        duration: const Duration(minutes: 90),
        from: _from,
      );
      final full = slots.where((s) => s.everyone).toList();

      expect(full.map(_label), ['11/11 18:00-19:30', '18/11 18:00-19:30']);
      expect(full.first.available, hasLength(4));
      expect(full.first.isFlexible, isFalse);
    });

    test('SQL (2 h): Wednesday 18:00 and a flexible Saturday morning', () {
      final slots = proposeSlots(
        participants: _group([demoSarah, demoAmine]),
        duration: const Duration(hours: 2),
        from: _from,
      );
      final full = slots.where((s) => s.everyone).map(_label).toList();

      expect(full.first, '11/11 18:00-20:00');
      expect(full, contains('14/11 10:00-12:00 (jusqu\'à 10:30)'));
    });

    test('Réseaux (1 h): a flexible Wednesday and Saturday 11:00', () {
      final slots = proposeSlots(
        participants: _group([demoYassine, demoAmine, demoInes]),
        duration: const Duration(hours: 1),
        from: _from,
      );
      final full = slots.where((s) => s.everyone).map(_label).toList();

      expect(full, contains('11/11 18:00-19:00 (jusqu\'à 18:30)'));
      expect(full, contains('14/11 11:00-12:00'));
    });

    test('Flutter (2 h): no common slot, only compromises', () {
      final slots = proposeSlots(
        participants: _group([demoSarah, demoYassine, demoInes, demoAmine]),
        duration: const Duration(hours: 2),
        from: _from,
      );

      expect(slots, isNotEmpty);
      expect(slots.any((s) => s.everyone), isFalse);
      // Les meilleurs compromis réunissent 4 personnes sur 5.
      expect(slots.first.available, hasLength(4));
      expect(slots.first.missing, hasLength(1));
      for (final slot in slots) {
        expect(slot.available.length, greaterThanOrEqualTo(3));
      }
    });

    test('compromises are sorted by number of people, then date', () {
      final slots = proposeSlots(
        participants: _group([demoSarah, demoYassine, demoInes, demoAmine]),
        duration: const Duration(hours: 2),
        from: _from,
      );

      for (var i = 1; i < slots.length; i++) {
        final previous = slots[i - 1];
        final current = slots[i];
        expect(
          previous.available.length > current.available.length ||
              (previous.available.length == current.available.length &&
                  !previous.start.isAfter(current.start)),
          isTrue,
          reason: '${_label(previous)} avant ${_label(current)}',
        );
      }
    });
  });

  group('proposeSlots rules', () {
    test('skips slots that already started', () {
      final slots = proposeSlots(
        participants: _group([demoSarah, demoYassine, demoInes]),
        duration: const Duration(minutes: 90),
        from: DateTime(2026, 11, 11, 18, 0),
      );

      expect(
        slots.where((s) => s.everyone).map(_label),
        ['18/11 18:00-19:30'],
      );
    });

    test('a busy period removes only that participant\'s slots', () {
      final slots = proposeSlots(
        participants: _group([demoSarah, demoYassine, demoInes]),
        duration: const Duration(minutes: 90),
        from: _from,
        busy: {
          _me: [(
            start: DateTime(2026, 11, 11, 18, 30),
            end: DateTime(2026, 11, 11, 19, 0),
          )],
        },
      );

      final full = slots.where((s) => s.everyone).map(_label).toList();
      expect(full, ['18/11 18:00-19:30']);
      // Le 11 à 18:00, je suis pris : le créneau reste proposé comme compromis
      // où c'est moi qui manque.
      final compromise = slots.firstWhere(
        (s) => s.start == DateTime(2026, 11, 11, 18),
      );
      expect(compromise.everyone, isFalse);
      expect(compromise.missing.map((p) => p.id), [_me]);
    });

    test('a busy period that only touches the slot does not block it', () {
      final slots = proposeSlots(
        participants: _group([demoSarah, demoYassine, demoInes]),
        duration: const Duration(minutes: 90),
        from: _from,
        busy: {
          _me: [(
            start: DateTime(2026, 11, 11, 19, 30),
            end: DateTime(2026, 11, 11, 20, 30),
          )],
        },
      );

      expect(
        slots.where((s) => s.everyone).map(_label),
        ['11/11 18:00-19:30', '18/11 18:00-19:30'],
      );
    });

    test('works for a single participant and refuses invalid input', () {
      final alone = proposeSlots(
        participants: [_owner()],
        duration: const Duration(hours: 1),
        from: _from,
        maxFull: 3,
      );
      expect(alone, hasLength(3));
      expect(alone.every((s) => s.everyone), isTrue);

      expect(
        proposeSlots(
          participants: const [],
          duration: const Duration(hours: 1),
          from: _from,
        ),
        isEmpty,
      );
      expect(
        proposeSlots(
          participants: [_owner()],
          duration: Duration.zero,
          from: _from,
        ),
        isEmpty,
      );
    });

    test('nobody available means no proposal at all', () {
      final slots = proposeSlots(
        participants: const [
          Participant(id: 'a', name: 'A'),
          Participant(id: 'b', name: 'B'),
        ],
        duration: const Duration(hours: 1),
        from: _from,
      );

      expect(slots, isEmpty);
    });

    test('limits the number of proposals', () {
      final slots = proposeSlots(
        participants: [_owner()],
        duration: const Duration(minutes: 30),
        from: _from,
        maxFull: 2,
      );

      expect(slots, hasLength(2));
    });
  });
}
