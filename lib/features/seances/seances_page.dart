import 'package:flutter/material.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/features/seances/proposer_seance_page.dart';
import 'package:studymate/features/seances/seances_store.dart';
import 'package:studymate/features/seances/widgets/seance_card.dart';
import 'package:studymate/features/seances/widgets/study_header.dart';
import 'package:studymate/theme/app_colors.dart';

class SeancesPage extends StatelessWidget {
  const SeancesPage({super.key, required this.store});

  final SeancesStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final sessions = store.items;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          children: [
            const StudyHeader(),
            const SizedBox(height: 26),
            const Text(
              'Tes prochaines séances',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 30,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Un rendez-vous avec ta progression.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 22),
            _ProposeButton(
              onPressed: () => _openPropose(context),
            ),
            const SizedBox(height: 16),
            _FormatFilters(
              selected: store.format,
              onSelected: store.setFormat,
            ),
            const SizedBox(height: 18),
            if (sessions.isEmpty)
              const _EmptySessions()
            else
              for (final seance in sessions) ...[
                SeanceCard(
                  seance: seance,
                  onReserve: () => store.toggleReservation(seance.id),
                ),
                const SizedBox(height: 14),
              ],
          ],
        );
      },
    );
  }

  Future<void> _openPropose(BuildContext context) async {
    final created = await Navigator.of(context).push<Seance>(
      MaterialPageRoute(builder: (_) => const ProposerSeancePage()),
    );
    if (created != null) {
      store.add(created);
    }
  }
}

class _ProposeButton extends StatelessWidget {
  const _ProposeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('Proposer une séance'),
      ),
    );
  }
}

class _FormatFilters extends StatelessWidget {
  const _FormatFilters({
    required this.selected,
    required this.onSelected,
  });

  final SessionFormat? selected;
  final ValueChanged<SessionFormat?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'Toutes',
            icon: Icons.calendar_month_outlined,
            active: selected == null,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: 'En ligne',
            icon: Icons.videocam_outlined,
            active: selected == SessionFormat.online,
            onTap: () => onSelected(SessionFormat.online),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: 'Présentiel',
            icon: Icons.location_on_outlined,
            active: selected == SessionFormat.inPerson,
            onTap: () => onSelected(SessionFormat.inPerson),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : const Color(0xFF8A8498);
    return Material(
      color: active ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: active ? null : Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySessions extends StatelessWidget {
  const _EmptySessions();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.event_busy_outlined, color: AppColors.subtle, size: 36),
          SizedBox(height: 10),
          Text(
            'Aucune séance pour ce filtre.',
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
