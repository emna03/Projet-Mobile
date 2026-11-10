import 'package:flutter/material.dart';
import 'package:studymate/features/availability/availability_editor.dart';
import 'package:studymate/features/availability/availability_models.dart';
import 'package:studymate/features/availability/common_slots.dart';
import 'package:studymate/features/calendar/calendar_event.dart';
import 'package:studymate/features/calendar/google_calendar_api.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/features/seances/seances_store.dart';
import 'package:studymate/theme/app_colors.dart';

/// Jours sur lesquels on cherche un créneau.
const slotSearchDays = 14;

/// Propose des créneaux où tous les participants d'une séance sont libres.
class CommonSlotsPage extends StatefulWidget {
  const CommonSlotsPage({
    super.key,
    required this.store,
    required this.seance,
    this.clock,
  });

  final SeancesStore store;
  final Seance seance;

  /// Horloge remplaçable dans les tests.
  final DateTime Function()? clock;

  @override
  State<CommonSlotsPage> createState() => _CommonSlotsPageState();
}

class _CommonSlotsPageState extends State<CommonSlotsPage> {
  late Seance _seance = widget.seance;
  List<Participant> _participants = const [];
  bool _loading = true;
  bool _useCalendar = false;
  bool _calendarLoading = false;
  String? _calendarError;
  List<CalendarEvent> _events = const [];

  DateTime get _now => (widget.clock ?? DateTime.now)();

  Duration get _duration {
    final interval = seanceInterval(_seance);
    return interval.end.difference(interval.start);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final participants = await widget.store.participantsFor(_seance.id);
    if (!mounted) return;
    setState(() {
      _participants = participants;
      _loading = false;
    });
  }

  Map<String, List<BusyRange>> _busy() {
    if (!_useCalendar) return const {};
    final me = widget.store.user.id;
    return {
      me: [
        for (final event in _events)
          // L'événement de cette séance ne doit pas bloquer ses propres créneaux.
          if (!event.allDay &&
              event.seanceId != _seance.id &&
              event.id != _seance.calendarEventId)
            (start: event.start, end: event.end),
      ],
    };
  }

  Future<void> _toggleCalendar(bool value) async {
    if (!value) {
      setState(() {
        _useCalendar = false;
        _calendarError = null;
      });
      return;
    }
    setState(() {
      _calendarLoading = true;
      _calendarError = null;
    });
    final today = DateTime(_now.year, _now.month, _now.day);
    try {
      final events = await widget.store.calendar.listEvents(
        from: today,
        to: today.add(const Duration(days: slotSearchDays + 1)),
      );
      if (!mounted) return;
      setState(() {
        _events = events;
        _useCalendar = true;
        _calendarLoading = false;
      });
    } on CalendarApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _useCalendar = false;
        _calendarLoading = false;
        _calendarError = error.message;
      });
    }
  }

  Future<void> _edit(Participant participant) async {
    await showAvailabilityEditor(
      context: context,
      participant: participant,
      onSave: (windows) async {
        await widget.store.saveAvailability(participant.id, windows);
        if (!mounted) return;
        setState(() {
          _participants = [
            for (final p in _participants)
              p.id == participant.id ? p.withWindows(windows) : p,
          ];
        });
      },
    );
  }

  Future<void> _addParticipant() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _ParticipantNameDialog(),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final added = await widget.store.addParticipant(_seance.id, name);
    if (!mounted) return;
    setState(() => _participants = [..._participants, added]);
    await _edit(added);
  }

  Future<void> _remove(Participant participant) async {
    await widget.store.removeParticipant(_seance.id, participant.id);
    if (!mounted) return;
    setState(() {
      _participants = _participants
          .where((p) => p.id != participant.id)
          .toList();
    });
  }

  Future<void> _choose(SlotProposal slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir ce créneau ?'),
        content: Text(
          'La séance « ${_seance.title} » aura lieu le '
          '${formatSeanceDay(slot.start)} de ${_clock(slot.start)} '
          'à ${_clock(slot.end)}.'
          '${slot.everyone ? '' : '\n\nAttention : ${_names(slot.missing)} '
                    'ne ${slot.missing.length > 1 ? 'sont' : 'est'} pas '
                    'disponible${slot.missing.length > 1 ? 's' : ''}.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Choisir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final next = _seance.copyWith(
      date: DateTime(slot.start.year, slot.start.month, slot.start.day),
      start: TimeOfDay(hour: slot.start.hour, minute: slot.start.minute),
      end: TimeOfDay(hour: slot.end.hour, minute: slot.end.minute),
    );
    final saved = await widget.store.update(next);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!saved) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible de modifier cette séance.')),
      );
      return;
    }
    setState(() => _seance = next);
    final warning = widget.store.takeCalendarWarning();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          warning ??
              'Séance déplacée au ${formatSeanceDay(slot.start)} à '
                  '${_clock(slot.start)}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slots = _loading
        ? const <SlotProposal>[]
        : proposeSlots(
            participants: _participants,
            duration: _duration,
            from: _now,
            days: slotSearchDays,
            busy: _busy(),
          );
    final withAvailability = _participants
        .where((p) => p.windows.isNotEmpty)
        .length;
    final full = slots.where((s) => s.everyone).toList();
    final compromises = slots.where((s) => !s.everyone).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundTop,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Retour',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Expanded(
                    child: Text(
                      'Créneaux communs',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 0, 12),
                child: Text(
                  '${_seance.title} · durée ${_formatDuration(_duration)} · '
                  '$slotSearchDays prochains jours',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _SectionTitle(
                'Participants (${_participants.length})',
                trailing: TextButton.icon(
                  onPressed: _addParticipant,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Ajouter'),
                ),
              ),
              if (_loading)
                const LinearProgressIndicator(minHeight: 3)
              else
                for (final participant in _participants)
                  _ParticipantTile(
                    participant: participant,
                    onEdit: () => _edit(participant),
                    onRemove: participant.isMe
                        ? null
                        : () => _remove(participant),
                  ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primary,
                title: const Text(
                  'Tenir compte de mon Google Agenda',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  _calendarLoading
                      ? 'Lecture de ton agenda...'
                      : 'Tes rendez-vous bloquent tes créneaux.',
                ),
                value: _useCalendar,
                onChanged: _calendarLoading ? null : _toggleCalendar,
              ),
              if (_calendarError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Google Agenda indisponible : $_calendarError',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              const _SectionTitle('Créneaux proposés'),
              if (_loading)
                const SizedBox.shrink()
              else if (withAvailability == 0)
                const _Hint(
                  'Personne n\'a encore indiqué de disponibilités. Touche un '
                  'participant pour renseigner ses plages libres.',
                )
              else if (slots.isEmpty)
                _Hint(
                  'Aucun créneau de ${_formatDuration(_duration)} ne convient '
                  'à au moins la moitié des participants sur les '
                  '$slotSearchDays prochains jours. Élargis les '
                  'disponibilités ou raccourcis la séance.',
                )
              else ...[
                if (full.isNotEmpty) ...[
                  const _GroupLabel('Tout le monde est disponible'),
                  for (final slot in full)
                    _SlotCard(
                      slot: slot,
                      current: _isCurrent(slot),
                      total: _participants.length,
                      onChoose: () => _choose(slot),
                    ),
                ] else
                  const _Hint(
                    'Aucun créneau ne convient à tout le monde. Voici les '
                    'meilleurs compromis.',
                  ),
                if (compromises.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const _GroupLabel('Meilleurs compromis'),
                  for (final slot in compromises)
                    _SlotCard(
                      slot: slot,
                      current: _isCurrent(slot),
                      total: _participants.length,
                      onChoose: () => _choose(slot),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isCurrent(SlotProposal slot) {
    final interval = seanceInterval(_seance);
    return interval.start == slot.start;
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

String _clock(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

String _names(List<Participant> people) => people.map((p) => p.name).join(', ');

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours == 0) return '$minutes min';
  if (minutes == 0) return '$hours h';
  return '$hours h ${_two(minutes)}';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
    required this.onEdit,
    required this.onRemove,
  });

  final Participant participant;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          onTap: onEdit,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          leading: CircleAvatar(
            backgroundColor: AppColors.avatar,
            child: Text(
              participant.initials,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          title: Text(
            participant.isMe ? '${participant.name} (toi)' : participant.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            summarizeWindows(participant.windows),
            style: TextStyle(
              color: participant.windows.isEmpty
                  ? AppColors.dot
                  : AppColors.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: onRemove == null
              ? const Icon(
                  Icons.edit_calendar_outlined,
                  color: AppColors.primary,
                )
              : IconButton(
                  tooltip: 'Retirer ${participant.name}',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.current,
    required this.total,
    required this.onChoose,
  });

  final SlotProposal slot;
  final bool current;
  final int total;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final latest = slot.isFlexible
        ? ' · début possible jusqu\'à ${_clock(slot.latestStart)}'
        : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(
            color: slot.everyone ? AppColors.green : AppColors.dot,
            width: 5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatSeanceDay(slot.start),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_clock(slot.start)} – ${_clock(slot.end)}$latest',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  slot.everyone
                      ? 'Les $total participants sont disponibles'
                      : '${slot.available.length} sur $total disponibles · '
                            'manque : ${_names(slot.missing)}',
                  style: TextStyle(
                    color: slot.everyone ? AppColors.green : AppColors.dot,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (current)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                'Actuel',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            FilledButton(
              onPressed: onChoose,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Choisir'),
            ),
        ],
      ),
    );
  }
}

class _ParticipantNameDialog extends StatefulWidget {
  const _ParticipantNameDialog();

  @override
  State<_ParticipantNameDialog> createState() => _ParticipantNameDialogState();
}

class _ParticipantNameDialogState extends State<_ParticipantNameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un participant'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Prénom Nom'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
