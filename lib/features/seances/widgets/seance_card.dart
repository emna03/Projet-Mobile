import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studymate/features/conflicts/schedule_conflicts.dart';
import 'package:studymate/features/meet/meet_space.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class SeanceCard extends StatelessWidget {
  const SeanceCard({
    super.key,
    required this.seance,
    required this.isOwner,
    required this.onReserve,
    this.onEdit,
    this.onDelete,
    this.onManageMeet,
    this.onToggleCalendar,
    this.calendarBusy = false,
    this.onFindSlots,
    this.conflicts = const [],
    this.unavailable = const [],
  });

  final Seance seance;
  final bool isOwner;
  final VoidCallback onReserve;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onManageMeet;

  /// Ouvre la recherche de créneaux communs (propriétaire seulement).
  final VoidCallback? onFindSlots;

  /// Mes autres séances dont l'horaire chevauche celle-ci.
  final List<Seance> conflicts;

  /// Participants qui ne sont pas libres à l'heure de cette séance.
  final List<String> unavailable;

  /// Null quand la séance ne peut pas encore aller dans l'agenda.
  final VoidCallback? onToggleCalendar;
  final bool calendarBusy;

  @override
  Widget build(BuildContext context) {
    final full = !seance.reserved && seance.seatsLeft == 0;
    final placeIcon = seance.isOnline
        ? Icons.video_camera_front_outlined
        : Icons.location_on_outlined;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A5AE0).withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                seance.subject,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (isOwner) ...[const _OwnerBadge(), const SizedBox(width: 8)],
              _ModeBadge(online: seance.isOnline),
              if (isOwner &&
                  (onEdit != null ||
                      onDelete != null ||
                      onManageMeet != null ||
                      onFindSlots != null))
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: AppColors.muted,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'meet') onManageMeet?.call();
                    if (value == 'slots') onFindSlots?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Modifier'),
                      ),
                    if (onFindSlots != null)
                      const PopupMenuItem(
                        value: 'slots',
                        child: Text('Trouver un créneau commun'),
                      ),
                    if (onManageMeet != null)
                      const PopupMenuItem(
                        value: 'meet',
                        child: Text('Gérer Google Meet'),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Supprimer'),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            seance.title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Avec ${seance.host}',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: AppColors.subtle,
              ),
              const SizedBox(width: 6),
              Text(
                formatSeanceDay(seance.date),
                style: const TextStyle(
                  color: Color(0xFF6F6A7D),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 14),
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: AppColors.subtle,
              ),
              const SizedBox(width: 6),
              Text(
                '${formatSeanceTime(seance.start)} – ${formatSeanceTime(seance.end)}',
                style: const TextStyle(
                  color: Color(0xFF6F6A7D),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _PlaceLine(seance: seance, icon: placeIcon),
          if (conflicts.isNotEmpty || unavailable.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ConflictBanner(
              conflicts: conflicts,
              unavailable: unavailable,
              onFindSlots: onFindSlots,
            ),
          ],
          if (onToggleCalendar != null) ...[
            const SizedBox(height: 6),
            _CalendarButton(
              inCalendar: seance.inCalendar,
              busy: calendarBusy,
              onPressed: calendarBusy ? null : onToggleCalendar,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seance.priceText,
                      style: TextStyle(
                        color: seance.free ? AppColors.green : AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _seatsLabel(seance.seatsLeft),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _ReserveButton(
                reserved: seance.reserved,
                full: full,
                onPressed: full ? null : onReserve,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _seatsLabel(int seats) {
    if (seats <= 0) return 'Complet';
    if (seats == 1) return '1 place disponible';
    return '$seats places disponibles';
  }
}

class _PlaceLine extends StatelessWidget {
  const _PlaceLine({required this.seance, required this.icon});

  final Seance seance;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final link = Uri.tryParse(seance.place.trim());
    final code = seance.meetCode ?? meetingCodeFromLink(seance.place);
    final canJoin = seance.isOnline && code != null && link != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: canJoin
              ? () => launchUrl(link, mode: LaunchMode.externalApplication)
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.subtle),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  canJoin ? 'Rejoindre Google Meet' : seance.place,
                  style: TextStyle(
                    color: canJoin
                        ? AppColors.primary
                        : const Color(0xFF6F6A7D),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (canJoin)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Copier le lien',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: seance.place.trim()),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lien Google Meet copié.')),
                    );
                  },
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
        if (code != null)
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              'Code $code',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _OwnerBadge extends StatelessWidget {
  const _OwnerBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Ta séance',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.badge,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        online ? 'En ligne' : 'Présentiel',
        style: const TextStyle(
          color: Color(0xFF9A96A8),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({
    required this.conflicts,
    required this.unavailable,
    required this.onFindSlots,
  });

  final List<Seance> conflicts;
  final List<String> unavailable;
  final VoidCallback? onFindSlots;

  static const _red = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9E6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (conflicts.isNotEmpty)
            _line(
              Icons.warning_amber_rounded,
              'Conflit d\'horaire : chevauche '
              '${conflicts.map(describeSeanceSlot).join(' et ')}',
            ),
          if (conflicts.isNotEmpty && unavailable.isNotEmpty)
            const SizedBox(height: 6),
          if (unavailable.isNotEmpty)
            _line(
              Icons.person_off_outlined,
              'Indisponible à cette heure : ${unavailable.join(', ')}',
            ),
          if (onFindSlots != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onFindSlots,
                style: TextButton.styleFrom(
                  foregroundColor: _red,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Trouver un autre créneau'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _red),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarButton extends StatelessWidget {
  const _CalendarButton({
    required this.inCalendar,
    required this.busy,
    required this.onPressed,
  });

  final bool inCalendar;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = busy
        ? 'Synchronisation...'
        : (inCalendar ? 'Dans Google Agenda · Retirer' : 'Ajouter à Google Agenda');
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: inCalendar ? AppColors.green : AppColors.primary,
        ),
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                inCalendar
                    ? Icons.event_available_rounded
                    : Icons.edit_calendar_outlined,
                size: 18,
              ),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
    );
  }
}

class _ReserveButton extends StatelessWidget {
  const _ReserveButton({
    required this.reserved,
    required this.full,
    required this.onPressed,
  });

  final bool reserved;
  final bool full;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = full ? 'Complet' : (reserved ? 'Réservé' : 'Réserver');
    final background = reserved ? AppColors.primarySoft : Colors.white;
    final foreground = full ? AppColors.muted : AppColors.primary;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: reserved
                ? null
                : Border.all(
                    color: full ? AppColors.line : AppColors.primarySoft,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (reserved) ...[
                Icon(Icons.check_rounded, size: 18, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: foreground,
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
