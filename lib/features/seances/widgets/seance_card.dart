import 'package:flutter/material.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/theme/app_colors.dart';

class SeanceCard extends StatelessWidget {
  const SeanceCard({
    super.key,
    required this.seance,
    required this.onReserve,
  });

  final Seance seance;
  final VoidCallback onReserve;

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
              _ModeBadge(online: seance.isOnline),
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
              const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.subtle),
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
              const Icon(Icons.schedule_rounded, size: 16, color: AppColors.subtle),
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
          Row(
            children: [
              Icon(placeIcon, size: 16, color: AppColors.subtle),
              const SizedBox(width: 6),
              Text(
                seance.place,
                style: const TextStyle(
                  color: Color(0xFF6F6A7D),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
                : Border.all(color: full ? AppColors.line : AppColors.primarySoft),
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
