import 'package:flutter/material.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/features/weather/open_meteo_api.dart';
import 'package:studymate/features/weather/weather_models.dart';
import 'package:studymate/theme/app_colors.dart';

/// Météo du jour d'une séance en présentiel, au début et à la fin de la séance.
class WeatherCard extends StatefulWidget {
  const WeatherCard({
    super.key,
    required this.date,
    required this.start,
    required this.end,
    this.api,
  });

  final DateTime date;
  final TimeOfDay start;
  final TimeOfDay end;

  /// Service météo, [openMeteoApi] par défaut.
  final OpenMeteoApi? api;

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  WeatherPlace _place = defaultWeatherPlace;
  WeatherForecast? _forecast;
  bool _loading = true;
  String? _error;
  int _request = 0;

  OpenMeteoApi get _api => widget.api ?? openMeteoApi;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(WeatherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La prévision couvre toute la journée : seul un autre jour la change.
    if (!_sameDay(oldWidget.date, widget.date)) _load();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final forecast = await _api.forecast(_place, widget.date);
      if (!mounted || request != _request) return;
      setState(() {
        _forecast = forecast;
        _loading = false;
      });
    } on WeatherApiException catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _forecast = null;
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _changePlace() async {
    final query = await showDialog<String>(
      context: context,
      builder: (context) => _PlaceDialog(initial: _place.name),
    );
    if (query == null || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final place = await _api.findPlace(query);
      if (!mounted) return;
      _place = place;
      await _load();
    } on WeatherApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primarySoft, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wb_twilight_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Météo · ${_place.label} · ${formatSeanceDay(widget.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Changer de ville',
                onPressed: _loading ? null : _changePlace,
                icon: const Icon(Icons.edit_location_alt_outlined, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _body(),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(minHeight: 3),
          SizedBox(height: 8),
          Text(
            'Chargement de la météo...',
            style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }
    final error = _error;
    if (error != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: _load, child: const Text('Réessayer')),
        ],
      );
    }
    final forecast = _forecast;
    if (forecast == null) return const SizedBox.shrink();

    final startHour = nearestHour(widget.start);
    final endHour = nearestHour(widget.end);
    final atStart = forecast.at(startHour);
    final atEnd = forecast.at(endHour);
    final advice = weatherAdvice(atStart, forecast.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _HourTile(
                title: 'Début · ${formatSeanceTime(widget.start)}',
                weather: atStart,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HourTile(
                title: 'Fin · ${formatSeanceTime(widget.end)}',
                weather: atEnd,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _daySummary(forecast.day),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (advice != null) ...[
          const SizedBox(height: 6),
          Text(
            advice,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  String _daySummary(DayWeather day) {
    final parts = <String>[
      if (day.minTemperature != null)
        'Min ${day.minTemperature!.round()}°',
      if (day.maxTemperature != null)
        'Max ${day.maxTemperature!.round()}°',
      if (day.precipitationProbability != null)
        'Pluie ${day.precipitationProbability!.round()} %',
    ];
    return parts.isEmpty ? '' : 'Journée : ${parts.join(' · ')}';
  }
}

class _HourTile extends StatelessWidget {
  const _HourTile({required this.title, required this.weather});

  final String title;
  final HourWeather? weather;

  @override
  Widget build(BuildContext context) {
    final hour = weather;
    final details = hour == null ? null : describeWeather(hour.code);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundTop,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (hour == null)
            const Text(
              'Indisponible',
              style: TextStyle(color: AppColors.muted),
            )
          else ...[
            Row(
              children: [
                Icon(details!.icon, color: AppColors.primary, size: 26),
                const SizedBox(width: 8),
                Text(
                  '${hour.temperature.round()}°',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              details.label,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hour.precipitationProbability != null ||
                hour.windKmh != null) ...[
              const SizedBox(height: 2),
              Text(
                [
                  if (hour.precipitationProbability != null)
                    'Pluie ${hour.precipitationProbability!.round()} %',
                  if (hour.windKmh != null)
                    'Vent ${hour.windKmh!.round()} km/h',
                ].join(' · '),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PlaceDialog extends StatefulWidget {
  const _PlaceDialog({required this.initial});

  final String initial;

  @override
  State<_PlaceDialog> createState() => _PlaceDialogState();
}

class _PlaceDialogState extends State<_PlaceDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ville de la séance'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(hintText: 'Tunis, Sfax, Sousse...'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Rechercher'),
        ),
      ],
    );
  }
}
