import 'package:flutter/material.dart';
import 'package:studymate/features/notifications/seance_reminders.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/features/seances/seances_store.dart';
import 'package:studymate/theme/app_colors.dart';

/// Ouvre le panneau des notifications de séances.
Future<void> showSeanceNotifications({
  required BuildContext context,
  required SeancesStore store,
  DateTime Function()? clock,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => NotificationsSheet(store: store, clock: clock),
  );
}

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key, required this.store, this.clock});

  final SeancesStore store;
  final DateTime Function()? clock;

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  bool? _enabled;
  bool _busy = false;
  String? _message;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _checkEnabled();
  }

  Future<void> _checkEnabled() async {
    final enabled = await widget.store.notificationsEnabled();
    if (!mounted) return;
    setState(() => _enabled = enabled);
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    final granted = await widget.store.enableNotifications();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _enabled = granted;
      _message = granted
          ? 'Notifications activées.'
          : 'Autorisation refusée. Active-la dans les réglages du téléphone : '
                'Applications → StudyMate → Notifications.';
    });
  }

  Future<void> _sendTest() async {
    setState(() => _busy = true);
    final sent = await widget.store.sendTestNotification();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = sent
          ? 'Notification de test envoyée : regarde le haut de ton écran.'
          : 'Impossible d\'envoyer la notification. Vérifie que les '
                'notifications de StudyMate sont autorisées.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
          child: AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) {
              final alerts = widget.store.alerts(now: _now);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Un rappel ${reminderLead.inMinutes} minutes avant chaque '
                    'séance que tu proposes ou que tu as réservée.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _StatusCard(
                    enabled: _enabled,
                    busy: _busy,
                    onEnable: _enable,
                    onTest: _sendTest,
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _message!,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text(
                    'Séances à venir',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (alerts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Aucune séance à venir. Réserve ou propose une séance '
                        'pour être prévenu.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    for (final alert in alerts) _AlertTile(alert: alert),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.enabled,
    required this.busy,
    required this.onEnable,
    required this.onTest,
  });

  final bool? enabled;
  final bool busy;
  final VoidCallback onEnable;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final on = enabled ?? false;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: on ? const Color(0xFFE3F5EA) : const Color(0xFFFFF1E0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                on
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_outlined,
                color: on ? AppColors.green : AppColors.dot,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  enabled == null
                      ? 'Vérification...'
                      : (on
                            ? 'Notifications activées'
                            : 'Notifications désactivées'),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (enabled == false)
                FilledButton(
                  onPressed: busy ? null : onEnable,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Activer'),
                ),
              OutlinedButton.icon(
                onPressed: busy ? null : onTest,
                icon: const Icon(Icons.notification_add_outlined, size: 18),
                label: const Text('Envoyer un test'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

String _clock(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final SeanceAlert alert;

  @override
  Widget build(BuildContext context) {
    final seance = alert.seance;
    final status = alert.sent
        ? 'Rappel envoyé à ${_clock(alert.remindAt)}'
        : 'Rappel à ${_clock(alert.remindAt)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundTop,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            seance.isOnline
                ? Icons.video_camera_front_outlined
                : Icons.location_on_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seance.title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatSeanceDay(alert.start)} · '
                  '${formatSeanceTime(seance.start)} – '
                  '${formatSeanceTime(seance.end)}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      alert.sent
                          ? Icons.check_circle_outline_rounded
                          : Icons.alarm_rounded,
                      size: 16,
                      color: alert.sent ? AppColors.green : AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                        color: alert.sent ? AppColors.green : AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
