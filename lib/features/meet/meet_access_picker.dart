import 'package:flutter/material.dart';
import 'package:studymate/features/meet/meet_space.dart';
import 'package:studymate/theme/app_colors.dart';

class MeetAccessPicker extends StatelessWidget {
  const MeetAccessPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final MeetAccess value;
  final ValueChanged<MeetAccess> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Accès à la salle',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final access in MeetAccess.values)
              ChoiceChip(
                label: Text(access.label),
                selected: value == access,
                showCheckmark: false,
                backgroundColor: Colors.white,
                selectedColor: AppColors.primarySoft,
                side: BorderSide(
                  color: value == access ? AppColors.primary : AppColors.line,
                ),
                labelStyle: TextStyle(
                  color: value == access ? AppColors.primary : AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: enabled ? (_) => onChanged(access) : null,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value.hint,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
