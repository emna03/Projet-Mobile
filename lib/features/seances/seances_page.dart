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
            const SizedBox(height: 6),
            Text(
              'Connecté en tant que ${store.user.displayName}',
              style: const TextStyle(
                color: AppColors.subtle,
                fontSize: 13,
                fontWeight: FontWeight.w600,
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
            if (store.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Text(
                  store.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (store.loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    'Chargement des séances...',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else if (sessions.isEmpty)
              const _EmptySessions()
            else
              for (final seance in sessions) ...[
                SeanceCard(
                  seance: seance,
                  isOwner: store.isOwner(seance),
                  onReserve: () => store.toggleReservation(seance.id),
                  onEdit: store.isOwner(seance)
                      ? () => _openEdit(context, seance)
                      : null,
                  onDelete: store.isOwner(seance)
                      ? () => _confirmDelete(context, seance)
                      : null,
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
      final saved = await store.add(created);
      if (!saved && context.mounted) {
        _showDenied(context, 'Impossible de publier cette séance.');
      }
    }
  }

  Future<void> _openEdit(BuildContext context, Seance seance) async {
    if (!store.isOwner(seance)) {
      _showDenied(context, 'Tu ne peux modifier que tes propres séances.');
      return;
    }
    final updated = await Navigator.of(context).push<Seance>(
      MaterialPageRoute(builder: (_) => ProposerSeancePage(seance: seance)),
    );
    if (updated != null) {
      final saved = await store.update(updated);
      if (!saved && context.mounted) {
        _showDenied(context, 'Tu ne peux modifier que tes propres séances.');
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, Seance seance) async {
    if (!store.isOwner(seance)) {
      _showDenied(context, 'Tu ne peux supprimer que tes propres séances.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer la séance'),
          content: Text('Supprimer « ${seance.title} » ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      final deleted = await store.delete(seance.id);
      if (!deleted && context.mounted) {
        _showDenied(context, 'Tu ne peux supprimer que tes propres séances.');
      }
    }
  }

  void _showDenied(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
