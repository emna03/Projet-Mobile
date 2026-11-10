import 'package:flutter/material.dart';
import 'package:studymate/features/calendar/agenda_entries.dart';
import 'package:studymate/features/calendar/calendar_event.dart';
import 'package:studymate/features/calendar/google_calendar_api.dart';
import 'package:studymate/features/meet/meet_space.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/features/seances/seances_store.dart';
import 'package:studymate/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

const _monthNames = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Google Agenda de l'utilisateur, avec ses séances de révision réservées.
class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key, required this.store, this.initialMonth});

  final SeancesStore store;

  /// Mois affiché à l'ouverture. Aujourd'hui par défaut.
  final DateTime? initialMonth;

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  late DateTime _month;
  List<CalendarEvent> _events = const [];
  bool _loading = false;
  String? _error;
  int _request = 0;

  DateTime get _from => DateTime(_month.year, _month.month);
  DateTime get _to => DateTime(_month.year, _month.month + 1);

  @override
  void initState() {
    super.initState();
    final base = widget.initialMonth ?? DateTime.now();
    _month = DateTime(base.year, base.month);
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await widget.store.calendar.listEvents(
        from: _from,
        to: _to,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } on CalendarApiException catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _events = const [];
        _loading = false;
        _error = error.message;
      });
    }
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
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
          child: AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) {
              final entries = buildAgenda(
                events: _events,
                reserved: widget.store.reservedSeances,
                from: _from,
                to: _to,
              );
              final groups = groupByDay(entries);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    month: _month,
                    onPrevious: () => _shiftMonth(-1),
                    onNext: () => _shiftMonth(1),
                  ),
                  if (_loading) const LinearProgressIndicator(minHeight: 3),
                  if (_error != null)
                    _ErrorBanner(message: _error!, onRetry: _load),
                  Expanded(
                    child: groups.isEmpty
                        ? _EmptyAgenda(loading: _loading)
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                            children: [
                              for (final group in groups) ...[
                                _DayTitle(day: group.day),
                                for (final entry in group.entries) ...[
                                  _EntryCard(entry: entry),
                                  const SizedBox(height: 10),
                                ],
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Retour',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Text(
                'Mon agenda',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Mois précédent',
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  '${_monthNames[month.month - 1]} ${month.year}',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  tooltip: 'Mois suivant',
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.dot, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Google Agenda indisponible : $message '
              'Tes séances réservées restent affichées.',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          loading ? 'Chargement de ton agenda...' : 'Rien de prévu ce mois-ci.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DayTitle extends StatelessWidget {
  const _DayTitle({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        formatSeanceDay(day),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _clock(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final AgendaEntry entry;

  @override
  Widget build(BuildContext context) {
    final seance = entry.seance;
    final isSeance = entry.isSeance;
    final event = entry.event;
    final location = entry.location;
    final meetLink = isSeance && isGoogleMeetLink(seance!.place);
    final link = event?.htmlLink;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: link == null ? null : () => _open(link),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border(
              left: BorderSide(
                color: isSeance ? AppColors.primary : AppColors.subtle,
                width: 5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  entry.allDay
                      ? 'Journée'
                      : '${_clock(entry.start)}\n${_clock(entry.end)}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (isSeance)
                          const _Badge(
                            label: 'Séance réservée',
                            color: AppColors.primary,
                            background: AppColors.primarySoft,
                          )
                        else if (event?.fromStudyMate ?? false)
                          const _Badge(
                            label: 'StudyMate',
                            color: AppColors.green,
                            background: Color(0xFFE3F5EA),
                          ),
                      ],
                    ),
                    if (isSeance || (event?.fromStudyMate ?? false))
                      const SizedBox(height: 6),
                    Text(
                      entry.label,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16.5,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isSeance) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Avec ${seance!.host}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (location != null && !meetLink) ...[
                      const SizedBox(height: 4),
                      Text(
                        location,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (meetLink)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _open(seance.place.trim()),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.video_call_outlined, size: 18),
                          label: const Text('Rejoindre Google Meet'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
