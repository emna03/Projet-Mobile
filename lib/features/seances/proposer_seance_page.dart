import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/theme/app_colors.dart';

class ProposerSeancePage extends StatefulWidget {
  const ProposerSeancePage({super.key});

  @override
  State<ProposerSeancePage> createState() => _ProposerSeancePageState();
}

class _ProposerSeancePageState extends State<ProposerSeancePage> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _title = TextEditingController();
  final _host = TextEditingController();
  final _place = TextEditingController(text: 'Visioconférence');
  final _seats = TextEditingController(text: '6');

  SessionFormat _format = SessionFormat.online;
  bool _free = true;
  DateTime _date = DateTime(2026, 10, 12);
  TimeOfDay _start = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 19, minute: 30);

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
                          const Expanded(
                            child: Text(
                              'Proposer une séance',
                              style: TextStyle(
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
                                if (_place.text.trim().isEmpty ||
                                    _place.text == 'Salle B12') {
                                  _place.text = 'Visioconférence';
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
                                if (_place.text == 'Visioconférence') {
                                  _place.text = 'Salle B12';
                                }
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _Field(
                        label: _format == SessionFormat.online ? 'Lieu' : 'Salle',
                        controller: _place,
                        hint: 'Visioconférence',
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
                    child: const Text('Publier la séance'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    final seance = Seance(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      subject: _subject.text.trim(),
      title: _title.text.trim(),
      host: _host.text.trim(),
      date: _date,
      start: _start,
      end: _end,
      format: _format,
      place: _place.text.trim(),
      seatsLeft: seats,
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
