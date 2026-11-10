import 'package:flutter/material.dart';

class WeatherApiException implements Exception {
  const WeatherApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lieu dont on veut connaître la météo.
class WeatherPlace {
  const WeatherPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.country,
  });

  final String name;
  final String? country;
  final double latitude;
  final double longitude;

  String get label => country == null || country == name
      ? name
      : '$name, $country';
}

/// Lieu utilisé tant que l'utilisateur n'en choisit pas un autre.
const defaultWeatherPlace = WeatherPlace(
  name: 'Tunis',
  country: 'Tunisie',
  latitude: 36.81897,
  longitude: 10.16579,
);

/// Météo à une heure donnée.
class HourWeather {
  const HourWeather({
    required this.hour,
    required this.temperature,
    required this.code,
    this.precipitationProbability,
    this.windKmh,
  });

  final int hour;
  final double temperature;
  final int code;

  /// Probabilité de pluie en %, quand le modèle la fournit.
  final double? precipitationProbability;
  final double? windKmh;
}

/// Résumé de la journée.
class DayWeather {
  const DayWeather({
    required this.code,
    this.maxTemperature,
    this.minTemperature,
    this.precipitationProbability,
  });

  final int code;
  final double? maxTemperature;
  final double? minTemperature;
  final double? precipitationProbability;
}

/// Prévision d'un jour pour un lieu.
class WeatherForecast {
  const WeatherForecast({
    required this.place,
    required this.date,
    required this.day,
    required this.hours,
  });

  final WeatherPlace place;
  final DateTime date;
  final DayWeather day;

  /// Heures de la journée, indexées de 0 à 23.
  final Map<int, HourWeather> hours;

  HourWeather? at(int hour) => hours[hour];
}

/// Heure pleine la plus proche de [time] : 18:29 → 18 h, 18:30 → 19 h.
int nearestHour(TimeOfDay time) {
  final hour = time.minute >= 30 ? time.hour + 1 : time.hour;
  return hour > 23 ? 23 : hour;
}

/// Description française et icône d'un code météo WMO.
({String label, IconData icon}) describeWeather(int code) {
  return switch (code) {
    0 => (label: 'Ciel dégagé', icon: Icons.wb_sunny_outlined),
    1 => (label: 'Plutôt dégagé', icon: Icons.wb_sunny_outlined),
    2 => (label: 'Partiellement nuageux', icon: Icons.wb_cloudy_outlined),
    3 => (label: 'Couvert', icon: Icons.cloud_outlined),
    45 || 48 => (label: 'Brouillard', icon: Icons.foggy),
    51 || 53 || 55 => (label: 'Bruine', icon: Icons.grain),
    56 || 57 => (label: 'Bruine verglaçante', icon: Icons.grain),
    61 => (label: 'Pluie faible', icon: Icons.water_drop_outlined),
    63 => (label: 'Pluie', icon: Icons.water_drop_outlined),
    65 => (label: 'Forte pluie', icon: Icons.water_drop),
    66 || 67 => (label: 'Pluie verglaçante', icon: Icons.water_drop),
    71 || 73 || 75 => (label: 'Neige', icon: Icons.ac_unit),
    77 => (label: 'Grains de neige', icon: Icons.ac_unit),
    80 || 81 || 82 => (label: 'Averses', icon: Icons.umbrella_outlined),
    85 || 86 => (label: 'Averses de neige', icon: Icons.ac_unit),
    95 => (label: 'Orage', icon: Icons.thunderstorm_outlined),
    96 || 99 => (label: 'Orage avec grêle', icon: Icons.thunderstorm_outlined),
    _ => (label: 'Météo inconnue', icon: Icons.help_outline_rounded),
  };
}

/// Conseil court selon la météo à l'heure de la séance, ou null.
String? weatherAdvice(HourWeather? hour, DayWeather day) {
  final rain = hour?.precipitationProbability ?? day.precipitationProbability;
  final temperature = hour?.temperature;
  if (rain != null && rain >= 50) {
    return 'Risque de pluie : prévois un parapluie ou un plan B.';
  }
  if (temperature != null && temperature >= 33) {
    return 'Forte chaleur prévue : pense à t\'hydrater.';
  }
  if (temperature != null && temperature <= 5) {
    return 'Il fera froid : couvre-toi bien.';
  }
  return null;
}
