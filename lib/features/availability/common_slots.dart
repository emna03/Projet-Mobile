import 'package:studymate/features/availability/availability_models.dart';

/// Période pendant laquelle quelqu'un est déjà pris (rendez-vous, cours...).
typedef BusyRange = ({DateTime start, DateTime end});

/// Créneau proposé pour une séance.
class SlotProposal {
  const SlotProposal({
    required this.start,
    required this.end,
    required this.latestStart,
    required this.available,
    required this.missing,
  });

  /// Premier début possible.
  final DateTime start;
  final DateTime end;

  /// Dernier début possible avec les mêmes personnes libres. Égal à [start]
  /// quand le créneau n'a aucune marge.
  final DateTime latestStart;
  final List<Participant> available;
  final List<Participant> missing;

  /// Tout le monde est libre.
  bool get everyone => missing.isEmpty;

  bool get isFlexible => latestStart.isAfter(start);
}

class _Run {
  _Run(this.key, this.firstMinute, this.available, this.missing)
    : lastMinute = firstMinute;

  final String key;
  final int firstMinute;
  int lastMinute;
  final List<Participant> available;
  final List<Participant> missing;
}

/// Cherche les créneaux de [duration] qui conviennent aux [participants] sur
/// les [days] jours à partir de [from].
///
/// Un participant est libre si une de ses plages hebdomadaires couvre tout le
/// créneau et qu'il n'a rien dans [busy] à ce moment. Les créneaux où tout le
/// monde est libre passent en premier. À défaut, on propose les meilleurs
/// compromis : au moins la moitié des participants, du plus nombreux au moins
/// nombreux. Les débuts consécutifs qui réunissent les mêmes personnes sont
/// regroupés en un seul créneau avec une marge ([SlotProposal.latestStart]).
List<SlotProposal> proposeSlots({
  required List<Participant> participants,
  required Duration duration,
  required DateTime from,
  int days = 14,
  Duration step = const Duration(minutes: 30),
  Map<String, List<BusyRange>> busy = const {},
  int maxFull = 6,
  int maxPartial = 5,
}) {
  final length = duration.inMinutes;
  if (participants.isEmpty || length <= 0 || days <= 0) return const [];
  final stepMinutes = step.inMinutes < 5 ? 5 : step.inMinutes;
  final minAvailable = (participants.length / 2).ceil();

  final full = <SlotProposal>[];
  final partial = <SlotProposal>[];

  for (var offset = 0; offset < days; offset++) {
    final day = DateTime(from.year, from.month, from.day + offset);
    _Run? run;

    void close() {
      final current = run;
      if (current == null) return;
      run = null;
      final proposal = SlotProposal(
        start: _at(day, current.firstMinute),
        end: _at(day, current.firstMinute + length),
        latestStart: _at(day, current.lastMinute),
        available: current.available,
        missing: current.missing,
      );
      (proposal.everyone ? full : partial).add(proposal);
    }

    for (var minute = 0; minute + length < 24 * 60; minute += stepMinutes) {
      final start = _at(day, minute);
      if (!start.isAfter(from)) {
        close();
        continue;
      }
      final end = _at(day, minute + length);

      final available = <Participant>[];
      final missing = <Participant>[];
      for (final participant in participants) {
        final free =
            participant.windows.any(
              (w) =>
                  w.weekday == day.weekday && w.covers(minute, minute + length),
            ) &&
            !(busy[participant.id] ?? const []).any(
              (range) => range.start.isBefore(end) && range.end.isAfter(start),
            );
        (free ? available : missing).add(participant);
      }

      if (available.length < minAvailable || available.isEmpty) {
        close();
        continue;
      }
      final key = available.map((p) => p.id).join('|');
      final current = run;
      if (current != null &&
          current.key == key &&
          current.lastMinute + stepMinutes == minute) {
        current.lastMinute = minute;
      } else {
        close();
        run = _Run(key, minute, available, missing);
      }
    }
    close();
  }

  full.sort((a, b) => a.start.compareTo(b.start));
  partial.sort((a, b) {
    final byCount = b.available.length.compareTo(a.available.length);
    return byCount != 0 ? byCount : a.start.compareTo(b.start);
  });
  return [
    ...full.take(maxFull),
    ...partial.take(full.isEmpty ? maxFull : maxPartial),
  ];
}

DateTime _at(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day, 0, minutes);
