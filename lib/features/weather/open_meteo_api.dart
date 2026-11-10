import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:studymate/features/weather/weather_models.dart';

/// Prévisions Open-Meteo (https://open-meteo.com), sans clé d'API.
class OpenMeteoApi {
  OpenMeteoApi({http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now,
      _ownsClient = client == null;

  static const _timeout = Duration(seconds: 15);

  /// Jours de prévision disponibles à partir d'aujourd'hui, aujourd'hui compris.
  static const forecastDays = 16;

  /// Jours passés pour lesquels le service garde des données.
  static const pastDays = 90;

  final http.Client _client;
  final DateTime Function() _clock;
  final bool _ownsClient;

  /// Cherche une ville par son nom et renvoie le résultat le plus probable.
  Future<WeatherPlace> findPlace(String query) async {
    final name = query.trim();
    if (name.length < 2) {
      throw const WeatherApiException('Saisis le nom d\'une ville.');
    }
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': name,
      'count': '1',
      'language': 'fr',
      'format': 'json',
    });
    final body = await _get(uri);
    final results = body['results'];
    if (results is! List || results.isEmpty || results.first is! Map) {
      throw WeatherApiException('Ville introuvable : $name.');
    }
    final first = Map<String, Object?>.from(results.first as Map);
    final latitude = first['latitude'];
    final longitude = first['longitude'];
    final found = first['name'];
    if (latitude is! num || longitude is! num || found is! String) {
      throw const WeatherApiException('Réponse de géolocalisation incomplète.');
    }
    final country = first['country'];
    return WeatherPlace(
      name: found,
      country: country is String ? country : null,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    );
  }

  /// Météo heure par heure de [date] à [place].
  Future<WeatherForecast> forecast(WeatherPlace place, DateTime date) async {
    final today = _dateOnly(_clock());
    final day = _dateOnly(date);
    final offset = day.difference(today).inDays;
    if (offset >= forecastDays) {
      throw const WeatherApiException(
        'Les prévisions sont disponibles jusqu\'à 16 jours à l\'avance. '
        'Reviens choisir cette date plus près du jour J.',
      );
    }
    if (offset < -pastDays) {
      throw const WeatherApiException(
        'La météo n\'est pas disponible pour une date aussi ancienne.',
      );
    }

    final key = _isoDate(day);
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': place.latitude.toString(),
      'longitude': place.longitude.toString(),
      'hourly': 'temperature_2m,precipitation_probability,weather_code,'
          'wind_speed_10m',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,'
          'precipitation_probability_max',
      'timezone': 'auto',
      'start_date': key,
      'end_date': key,
    });
    final body = await _get(uri);
    return _parse(body, place, day, key);
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<Map<String, Object?>> _get(Uri uri) async {
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on Exception {
      throw const WeatherApiException(
        'Météo indisponible. Vérifie ta connexion Internet.',
      );
    }

    Map<String, Object?> body = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) body = Map<String, Object?>.from(decoded);
    } catch (_) {
      // Géré plus bas avec le code de statut.
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final reason = body['reason'];
      throw WeatherApiException(
        reason is String && reason.isNotEmpty
            ? 'Météo indisponible : $reason'
            : 'Le service météo a répondu ${response.statusCode}.',
      );
    }
    return body;
  }

  WeatherForecast _parse(
    Map<String, Object?> body,
    WeatherPlace place,
    DateTime date,
    String key,
  ) {
    final hourly = body['hourly'];
    final daily = body['daily'];
    if (hourly is! Map || daily is! Map) {
      throw const WeatherApiException('La réponse météo est incomplète.');
    }

    final times = hourly['time'];
    if (times is! List) {
      throw const WeatherApiException('La réponse météo est incomplète.');
    }
    final hours = <int, HourWeather>{};
    for (var i = 0; i < times.length; i++) {
      final time = times[i];
      if (time is! String || !time.startsWith(key) || time.length < 13) continue;
      final hour = int.tryParse(time.substring(11, 13));
      final temperature = _number(hourly['temperature_2m'], i);
      final code = _number(hourly['weather_code'], i);
      if (hour == null || temperature == null || code == null) continue;
      hours[hour] = HourWeather(
        hour: hour,
        temperature: temperature,
        code: code.round(),
        precipitationProbability: _number(hourly['precipitation_probability'], i),
        windKmh: _number(hourly['wind_speed_10m'], i),
      );
    }
    if (hours.isEmpty) {
      throw const WeatherApiException('Aucune donnée météo pour cette date.');
    }

    final dayCode = _number(daily['weather_code'], 0);
    return WeatherForecast(
      place: place,
      date: date,
      hours: hours,
      day: DayWeather(
        code: (dayCode ?? hours.values.first.code).round(),
        maxTemperature: _number(daily['temperature_2m_max'], 0),
        minTemperature: _number(daily['temperature_2m_min'], 0),
        precipitationProbability: _number(
          daily['precipitation_probability_max'],
          0,
        ),
      ),
    );
  }

  double? _number(Object? list, int index) {
    if (list is! List || index >= list.length) return null;
    final value = list[index];
    return value is num ? value.toDouble() : null;
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _isoDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

final openMeteoApi = OpenMeteoApi();
