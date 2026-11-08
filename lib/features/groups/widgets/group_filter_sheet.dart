import 'package:flutter/material.dart';

import '../../../core/constants/academic_levels.dart';
import '../../../core/theme/app_theme.dart';
import '../models/group_filters.dart';

/// Opens the advanced filter bottom sheet.
///
/// Returns the filters chosen by the user when they tap "Appliquer", or
/// `null` if the sheet was dismissed.
Future<GroupFilters?> showGroupFilterSheet(
  BuildContext context, {
  required GroupFilters initial,
}) {
  return showModalBottomSheet<GroupFilters>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimensions.rCard),
      ),
    ),
    builder: (_) => GroupFilterSheet(initial: initial),
  );
}

class GroupFilterSheet extends StatefulWidget {
  final GroupFilters initial;

  const GroupFilterSheet({super.key, required this.initial});

  @override
  State<GroupFilterSheet> createState() => _GroupFilterSheetState();
}

class _GroupFilterSheetState extends State<GroupFilterSheet> {
  late VisibilityFilter _visibility;
  late CapacityFilter _capacity;
  String? _level;

  @override
  void initState() {
    super.initState();
    _visibility = widget.initial.visibility;
    _capacity = widget.initial.capacity;
    _level = widget.initial.level;
  }

  void _reset() {
    setState(() {
      _visibility = VisibilityFilter.all;
      _capacity = CapacityFilter.all;
      _level = null;
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      GroupFilters(visibility: _visibility, capacity: _capacity, level: _level),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(
              child: Text(
                'Filtrer les groupes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Visibilité ─────────────────────────────────────────────────
            const _SectionTitle('Visibilité', icon: Icons.visibility_outlined),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<VisibilityFilter>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: VisibilityFilter.all,
                    label: Text('Tous'),
                  ),
                  ButtonSegment(
                    value: VisibilityFilter.publicOnly,
                    label: Text('Publics'),
                    icon: Icon(Icons.public, size: 16),
                  ),
                  ButtonSegment(
                    value: VisibilityFilter.privateOnly,
                    label: Text('Privés'),
                    icon: Icon(Icons.lock_outline, size: 16),
                  ),
                ],
                selected: {_visibility},
                onSelectionChanged: (s) =>
                    setState(() => _visibility = s.first),
              ),
            ),
            const SizedBox(height: 22),

            // ── Disponibilité ──────────────────────────────────────────────
            const _SectionTitle('Disponibilité', icon: Icons.people_outline),
            const SizedBox(height: 6),
            ...CapacityFilter.values.map(
              (c) => _OptionTile(
                label: c.label,
                icon: switch (c) {
                  CapacityFilter.all => Icons.all_inclusive,
                  CapacityFilter.available => Icons.event_seat_outlined,
                  CapacityFilter.full => Icons.block_outlined,
                },
                selected: _capacity == c,
                onTap: () => setState(() => _capacity = c),
              ),
            ),
            const SizedBox(height: 16),

            // ── Niveau académique ──────────────────────────────────────────
            const _SectionTitle('Niveau académique', icon: Icons.school_outlined),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: _level,
              isExpanded: true,
              borderRadius: BorderRadius.circular(AppDimensions.rButton),
              decoration: const InputDecoration(
                fillColor: AppColors.surfaceLight,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tous les niveaux'),
                ),
                ...AcademicLevels.all.map(
                  (l) => DropdownMenuItem<String?>(value: l, child: Text(l)),
                ),
              ],
              onChanged: (v) => setState(() => _level = v),
            ),
            const SizedBox(height: 24),

            // ── Actions ────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Réinitialiser'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _apply,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle(this.title, {required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

/// Radio-style selectable row.
class _OptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.rButton),
          child: AnimatedContainer(
            duration: AppDimensions.anim,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppDimensions.rButton),
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: selected ? AppColors.primary : AppColors.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? AppColors.primary : AppColors.text,
                    ),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
