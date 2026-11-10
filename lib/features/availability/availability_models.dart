const _weekdayLabels = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];

/// Libellé court d'un jour, 1 = lundi … 7 = dimanche (comme [DateTime.weekday]).
String weekdayLabel(int weekday) => _weekdayLabels[(weekday - 1) % 7];

/// Minutes depuis minuit en `HH:MM`.
String formatMinutes(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Plage horaire récurrente chaque semaine pendant laquelle une personne est
/// libre, par exemple « le mercredi de 17:00 à 19:30 ».
class AvailabilityWindow {
  const AvailabilityWindow({
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
  });

  /// 1 = lundi … 7 = dimanche.
  final int weekday;
  final int startMinutes;
  final int endMinutes;

  /// Vrai si [start]–[end] (en minutes depuis minuit) tient dans la plage.
  bool covers(int start, int end) => start >= startMinutes && end <= endMinutes;

  Map<String, Object?> toMap(String userId) => {
    'user_id': userId,
    'weekday': weekday,
    'start_minutes': startMinutes,
    'end_minutes': endMinutes,
  };

  factory AvailabilityWindow.fromMap(Map<String, Object?> map) {
    return AvailabilityWindow(
      weekday: map['weekday']! as int,
      startMinutes: map['start_minutes']! as int,
      endMinutes: map['end_minutes']! as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AvailabilityWindow &&
      other.weekday == weekday &&
      other.startMinutes == startMinutes &&
      other.endMinutes == endMinutes;

  @override
  int get hashCode => Object.hash(weekday, startMinutes, endMinutes);
}

/// Trie [windows] et fusionne celles d'un même jour qui se chevauchent ou se
/// touchent. Les plages vides ou inversées sont ignorées.
List<AvailabilityWindow> normalizeWindows(
  Iterable<AvailabilityWindow> windows,
) {
  final sorted = windows.where((w) => w.endMinutes > w.startMinutes).toList()
    ..sort((a, b) {
      final byDay = a.weekday.compareTo(b.weekday);
      return byDay != 0 ? byDay : a.startMinutes.compareTo(b.startMinutes);
    });
  final merged = <AvailabilityWindow>[];
  for (final window in sorted) {
    if (merged.isNotEmpty) {
      final last = merged.last;
      if (last.weekday == window.weekday &&
          window.startMinutes <= last.endMinutes) {
        if (window.endMinutes > last.endMinutes) {
          merged[merged.length - 1] = AvailabilityWindow(
            weekday: last.weekday,
            startMinutes: last.startMinutes,
            endMinutes: window.endMinutes,
          );
        }
        continue;
      }
    }
    merged.add(window);
  }
  return merged;
}

/// Résumé lisible : « Lun., Mer. 16:00–20:00 · Sam. 10:00–14:00 ».
String summarizeWindows(List<AvailabilityWindow> windows) {
  if (windows.isEmpty) return 'Aucune disponibilité';
  final byRange = <String, List<int>>{};
  for (final window in normalizeWindows(windows)) {
    final range =
        '${formatMinutes(window.startMinutes)}–${formatMinutes(window.endMinutes)}';
    byRange.putIfAbsent(range, () => []).add(window.weekday);
  }
  return byRange.entries
      .map(
        (entry) => '${entry.value.map(weekdayLabel).join(', ')} ${entry.key}',
      )
      .join(' · ');
}

/// Personne invitée à une séance, avec ses disponibilités hebdomadaires.
class Participant {
  const Participant({
    required this.id,
    required this.name,
    this.windows = const [],
    this.isMe = false,
  });

  final String id;
  final String name;
  final List<AvailabilityWindow> windows;

  /// Vrai pour l'utilisateur connecté.
  final bool isMe;

  Participant withWindows(List<AvailabilityWindow> next) =>
      Participant(id: id, name: name, windows: next, isMe: isMe);

  String get initials {
    final letters = name
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return letters.isEmpty ? '?' : letters;
  }
}
