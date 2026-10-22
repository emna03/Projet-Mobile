import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studymate/features/auth/current_user.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class ProposerSeancePage extends StatefulWidget {
  const ProposerSeancePage({super.key, this.seance});

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

  bool get _editing => widget.seance != null;

  @override
  void initState() {
    super.initState();
    final seance = widget.seance;
    _subject = TextEditingController(text: seance?.subject ?? '');
    _title = TextEditingController(text: seance?.title ?? '');
    _host = TextEditingController(
      text: seance?.host ?? AuthSession.instance.user.displayName,
    );
    _place = TextEditingController(
      text: seance?.place ??
          (seance?.format == SessionFormat.inPerson ? 'Salle B12' : ''),
    );
    _seats = TextEditingController(text: '${seance?.seatsLeft ?? 6}');
    _format = seance?.format ?? SessionFormat.online;
    _free = seance?.free ?? true;
    _date = seance?.date ?? DateTime(2026, 10, 12);
    _start = seance?.start ?? const TimeOfDay(hour: 18, minute: 0);
    _end = seance?.end ?? const TimeOfDay(hour: 19, minute: 30);
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
                              _editing ? 'Modifier la séance' : 'Proposer une séance',
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
                                if (!_isMeetLink(_place.text)) {
                                  _place.clear();
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
                                    _isMeetLink(_place.text)) {
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
                          validator: (value) {
                            if (!_isMeetLink(value ?? '')) {
                              return 'Colle un lien Google Meet';
                            }
                            return null;
                          },
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _createMeetLink,
                            icon: const Icon(Icons.video_call_outlined),
                            label: const Text('Créer le lien sur Google Meet'),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 14),
                          child: Text(
                            'Google ouvre une nouvelle réunion. Copie le lien et colle-le ici.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
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
                      const SizedBox(height: 16),
                      _Field(
                        label: 'Places',
                        controller: _seats,
                        hint: '6',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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

  bool _isMeetLink(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https' || uri.host != 'meet.google.com') {
      return false;
    }
    final code = uri.path.replaceAll('/', '');
    return code.isNotEmpty && code != 'new';
  }

  Future<void> _createMeetLink() async {
    final uri = Uri.parse('https://meet.google.com/new');
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir Google Meet. $error')),
      );
    }
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
    final seance = Seance(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      ownerId: existing?.ownerId ?? AuthSession.instance.user.id,
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
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

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
            validator: validator ??
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
                borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
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
