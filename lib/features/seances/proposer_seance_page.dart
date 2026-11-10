import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studymate/features/meet/google_meet_api.dart';
import 'package:studymate/features/meet/meet_space.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/features/seances/seance_user.dart';
import 'package:studymate/features/weather/weather_card.dart';
import 'package:studymate/theme/app_colors.dart';

class ProposerSeancePage extends StatefulWidget {
  const ProposerSeancePage({
    super.key,
    required this.currentUser,
    this.seance,
  });

  final SeanceUser currentUser;
  final Seance? seance;

  @override
  State<ProposerSeancePage> createState() => _ProposerSeancePageState();
}

class _ProposerSeancePageState extends State<ProposerSeancePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _subject;
  late final TextEditingController _title;
  late final TextEditingController _host;
  late final TextEditingController _place;
  late final TextEditingController _seats;

  late SessionFormat _format;
  late bool _free;
  late DateTime _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  String? _meetSpaceName;
  String? _meetCode;
  MeetAccess _meetAccess = MeetAccess.open;
  bool _meetBusy = false;

  bool get _editing => widget.seance != null;

  @override
  void initState() {
    super.initState();
    final seance = widget.seance;
    _subject = TextEditingController(text: seance?.subject ?? '');
    _title = TextEditingController(text: seance?.title ?? '');
    _host = TextEditingController(
      text: seance?.host ?? widget.currentUser.displayName,
    );
    _place = TextEditingController(
      text:
          seance?.place ??
          (seance?.format == SessionFormat.inPerson ? 'Salle B12' : ''),
    );
    _seats = TextEditingController(text: '${seance?.seatsLeft ?? 6}');
    _format = seance?.format ?? SessionFormat.online;
    _free = seance?.free ?? true;
    _date = seance?.date ?? DateTime(2026, 10, 12);
    _start = seance?.start ?? const TimeOfDay(hour: 18, minute: 0);
    _end = seance?.end ?? const TimeOfDay(hour: 19, minute: 30);
    _meetSpaceName = seance?.meetSpaceName;
    _meetCode =
        seance?.meetCode ??
        (seance == null ? null : meetingCodeFromLink(seance.place));
    _meetAccess = MeetAccessDetails.parse(seance?.meetAccess);
  }

  @override
  void dispose() {
    _subject.dispose();
    _title.dispose();
    _host.dispose();
    _place.dispose();
    _seats.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      Row(
                        children: [
                          _CircleButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _editing
                                  ? 'Modifier la séance'
                                  : 'Proposer une séance',
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Partage une séance de révision avec le groupe.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _Field(
                        label: 'Matière',
                        controller: _subject,
                        hint: 'Docker',
                      ),
                      _Field(
                        label: 'Titre',
                        controller: _title,
                        hint: 'Docker, de zéro à déployé',
                      ),
                      _Field(
                        label: 'Animateur',
                        controller: _host,
                        hint: 'Yassine Trabelsi',
                      ),
                      const Text(
                        'Format',
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _Choice(
                              label: 'En ligne',
                              icon: Icons.videocam_outlined,
                              selected: _format == SessionFormat.online,
                              onTap: () => setState(() {
                                _format = SessionFormat.online;
                                if (!isGoogleMeetLink(_place.text)) {
                                  _place.text = _meetCode == null
                                      ? ''
                                      : 'https://meet.google.com/$_meetCode';
                                }
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Choice(
                              label: 'Présentiel',
                              icon: Icons.location_on_outlined,
                              selected: _format == SessionFormat.inPerson,
                              onTap: () => setState(() {
                                _format = SessionFormat.inPerson;
                                if (_place.text.trim().isEmpty ||
                                    isGoogleMeetLink(_place.text)) {
                                  _place.text = 'Salle B12';
                                }
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_format == SessionFormat.online) ...[
                        _Field(
                          label: 'Lien Google Meet',
                          controller: _place,
                          hint: 'https://meet.google.com/abc-defg-hij',
                          keyboardType: TextInputType.url,
                          onChanged: _onMeetLinkEdited,
                          validator: (value) {
                            if (!isGoogleMeetLink(value ?? '')) {
                              return 'Crée un lien Google Meet ou colle-le ici';
                            }
                            return null;
                          },
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _meetBusy ? null : _createMeetLink,
                            icon: _meetBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.video_call_outlined),
                            label: Text(
                              _meetSpaceName == null
                                  ? 'Créer le lien Google Meet'
                                  : 'Nouveau lien Google Meet',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'La salle est créée avec ton compte Google via l\'API Meet.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_meetCode != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Code $_meetCode',
                            style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        if (_meetSpaceName != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _meetBusy ? null : _endConference,
                              child: const Text('Terminer la réunion en cours'),
                            ),
                          )
                        else
                          const SizedBox(height: 14),
                      ] else
                        _Field(
                          label: 'Salle',
                          controller: _place,
                          hint: 'Salle B12',
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: _PickerTile(
                              label: 'Date',
                              value: formatSeanceDay(_date),
                              icon: Icons.calendar_today_outlined,
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PickerTile(
                              label: 'Horaire',
                              value:
                                  '${formatSeanceTime(_start)} – ${formatSeanceTime(_end)}',
                              icon: Icons.schedule_rounded,
                              onTap: _pickTimes,
                            ),
                          ),
                        ],
                      ),
                      if (_format == SessionFormat.inPerson) ...[
                        const SizedBox(height: 12),
                        WeatherCard(date: _date, start: _start, end: _end),
                      ],
                      const SizedBox(height: 16),
                      _Field(
                        label: 'Places',
                        controller: _seats,
                        hint: '6',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          final seats = int.tryParse(value ?? '');
                          if (seats == null || seats <= 0) {
                            return 'Indique un nombre de places';
                          }
                          return null;
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppColors.primary,
                        title: const Text(
                          'Séance gratuite',
                          style: TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        value: _free,
                        onChanged: (value) => setState(() => _free = value),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(_editing ? 'Enregistrer' : 'Publier la séance'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onMeetLinkEdited(String value) {
    final code = meetingCodeFromLink(value);
    if (code == _meetCode) return;
    setState(() {
      _meetCode = code;
      _meetSpaceName = null;
    });
  }

  Future<void> _createMeetLink() async {
    if (_meetBusy) return;
    if (_meetSpaceName != null) {
      final confirmed = await _confirm(
        'Nouveau lien Google Meet',
        'La séance utilisera une nouvelle salle. L\'ancien lien ne sera plus proposé.',
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _meetBusy = true);
    try {
      final space = await googleMeetApi.createSpace(access: _meetAccess);
      if (!mounted) return;
      setState(() {
        _place.text = space.meetingUri;
        _meetSpaceName = space.name;
        _meetCode = space.meetingCode;
        _meetAccess = space.access;
      });
      _showMessage('Lien Google Meet créé.');
    } on MeetApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _meetBusy = false);
    }
  }

  Future<void> _endConference() async {
    final spaceName = _meetSpaceName;
    if (spaceName == null || _meetBusy) return;
    final confirmed = await _confirm(
      'Terminer la réunion',
      'Tout le monde sera déconnecté de cette salle. Le lien reste valable.',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _meetBusy = true);
    try {
      await googleMeetApi.endActiveConference(spaceName);
      _showMessage('Réunion terminée. Le lien reste valable.');
    } on MeetApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _meetBusy = false);
    }
  }

  Future<bool?> _confirm(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continuer'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2026),
      lastDate: DateTime(2027, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTimes() async {
    final start = await showTimePicker(context: context, initialTime: _start);
    if (start == null || !mounted) return;
    final end = await showTimePicker(context: context, initialTime: _end);
    if (end == null || !mounted) return;
    setState(() {
      _start = start;
      _end = end;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final seats = int.parse(_seats.text);
    final existing = widget.seance;
    final online = _format == SessionFormat.online;
    final code = online ? meetingCodeFromLink(_place.text) : null;
    final linked = code != null && code == _meetCode && _meetSpaceName != null;
    final seance = Seance(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      ownerId: existing?.ownerId ?? widget.currentUser.id,
      subject: _subject.text.trim(),
      title: _title.text.trim(),
      host: _host.text.trim(),
      date: _date,
      start: _start,
      end: _end,
      format: _format,
      place: _place.text.trim(),
      seatsLeft: seats,
      reserved: existing?.reserved ?? false,
      free: _free,
      priceLabel: _free ? null : 'Payant',
      meetSpaceName: linked ? _meetSpaceName : null,
      meetCode: code,
      meetAccess: linked ? _meetAccess.apiValue : null,
      calendarEventId: existing?.calendarEventId,
    );
    Navigator.of(context).pop(seance);
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            validator:
                validator ??
                (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Champ obligatoire';
                  }
                  return null;
                },
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              hintStyle: const TextStyle(color: AppColors.subtle),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: selected ? null : Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.muted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: AppColors.subtle),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: AppColors.text),
        ),
      ),
    );
  }
}
