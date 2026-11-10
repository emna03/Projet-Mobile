import 'package:flutter/material.dart';
import 'package:studymate/features/availability/availability_models.dart';
import 'package:studymate/theme/app_colors.dart';

/// Ouvre l'éditeur des disponibilités hebdomadaires de [participant].
///
/// [onSave] est appelé à chaque ajout ou suppression, avec la liste complète
/// et fusionnée : rien ne se perd si on ferme le panneau.
Future<void> showAvailabilityEditor({
  required BuildContext context,
  required Participant participant,
  required Future<void> Function(List<AvailabilityWindow> windows) onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) =>
        AvailabilityEditor(participant: participant, onSave: onSave),
  );
}

class AvailabilityEditor extends StatefulWidget {
  const AvailabilityEditor({
    super.key,
    required this.participant,
    required this.onSave,
  });

  final Participant participant;
  final Future<void> Function(List<AvailabilityWindow> windows) onSave;

  @override
  State<AvailabilityEditor> createState() => _AvailabilityEditorState();
}

class _AvailabilityEditorState extends State<AvailabilityEditor> {
  late List<AvailabilityWindow> _windows = normalizeWindows(
    widget.participant.windows,
  );
  int _weekday = DateTime.monday;
  TimeOfDay _from = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 20, minute: 0);
  bool _busy = false;
  String? _error;

  int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

  Future<void> _pick({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _from : _to,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _from = picked;
      } else {
        _to = picked;
      }
      _error = null;
    });
  }

  Future<void> _commit(List<AvailabilityWindow> next) async {
    setState(() => _busy = true);
    try {
      await widget.onSave(next);
      if (!mounted) return;
      setState(() => _windows = next);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    if (_minutes(_to) <= _minutes(_from)) {
      setState(
        () => _error = 'L\'heure de fin doit être après l\'heure de début.',
      );
      return;
    }
    setState(() => _error = null);
    await _commit(
      normalizeWindows([
        ..._windows,
        AvailabilityWindow(
          weekday: _weekday,
          startMinutes: _minutes(_from),
          endMinutes: _minutes(_to),
        ),
      ]),
    );
  }

  Future<void> _remove(AvailabilityWindow window) {
    return _commit(_windows.where((w) => w != window).toList());
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom + keyboard),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.participant.isMe
                ? 'Mes disponibilités'
                : 'Disponibilités de ${widget.participant.name}',
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Plages libres qui se répètent chaque semaine.',
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          if (_windows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Aucune plage pour l\'instant.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            for (final window in _windows)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.event_available_outlined,
                  color: AppColors.primary,
                ),
                title: Text(
                  '${weekdayLabel(window.weekday)}  '
                  '${formatMinutes(window.startMinutes)} – '
                  '${formatMinutes(window.endMinutes)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: IconButton(
                  tooltip: 'Retirer cette plage',
                  onPressed: _busy ? null : () => _remove(window),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ),
          const SizedBox(height: 10),
          const Text(
            'Ajouter une plage',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                ChoiceChip(
                  label: Text(weekdayLabel(day)),
                  selected: _weekday == day,
                  showCheckmark: false,
                  selectedColor: AppColors.primarySoft,
                  onSelected: (_) => setState(() => _weekday = day),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(start: true),
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text('De ${_from.format(context)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(start: false),
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text('À ${_to.format(context)}'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _add,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter la plage'),
            ),
          ),
        ],
      ),
    );
  }
}
