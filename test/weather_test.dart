import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:studymate/features/weather/open_meteo_api.dart';
import 'package:studymate/features/weather/weather_card.dart';
import 'package:studymate/features/weather/weather_models.dart';

final _today = DateTime(2026, 11, 9);

http.Response _json(Map<String, Object?> body, [int status = 200]) {
  return http.Response(jsonEncode(body), status);
}

/// Prévision de [key] : 10 + heure °C, ciel plutôt dégagé, pluie à 20 %.
Map<String, Object?> _forecastBody(String key, {double rain = 20}) {
  final hours = List.generate(24, (hour) => hour);
  return {
    'hourly': {
      'time': [for (final h in hours) '${key}T${h.toString().padLeft(2, '0')}:00'],
      'temperature_2m': [for (final h in hours) 10.0 + h],
      'precipitation_probability': [for (final _ in hours) rain],
      'weather_code': [for (final _ in hours) 1],
      'wind_speed_10m': [for (final _ in hours) 12.0],
    },
    'daily': {
      'weather_code': [2],
      'temperature_2m_max': [33.4],
      'temperature_2m_min': [10.2],
      'precipitation_probability_max': [rain],
    },
  };
}

class _Server {
  _Server(this._handler);

  final http.Response Function(http.Request request) _handler;
  final requests = <http.Request>[];

  OpenMeteoApi get api => OpenMeteoApi(
    clock: () => _today,
    client: _ScriptedClient((request) async {
      requests.add(request);
      return _handler(request);
    }),
  );
}

http.Response _normal(http.Request request) {
  if (request.url.host == 'geocoding-api.open-meteo.com') {
    return _json({
      'results': [
        {
          'name': 'Sfax',
          'country': 'Tunisie',
          'latitude': 34.74,
          'longitude': 10.76,
        },
      ],
    });
  }
  return _json(_forecastBody(request.url.queryParameters['start_date']!));
}

void main() {
  group('weather helpers', () {
    test('rounds a time to the nearest hour without passing midnight', () {
      expect(nearestHour(const TimeOfDay(hour: 18, minute: 29)), 18);
      expect(nearestHour(const TimeOfDay(hour: 18, minute: 30)), 19);
      expect(nearestHour(const TimeOfDay(hour: 23, minute: 45)), 23);
    });

    test('describes WMO codes in French', () {
      expect(describeWeather(0).label, 'Ciel dégagé');
      expect(describeWeather(63).label, 'Pluie');
      expect(describeWeather(95).label, 'Orage');
      expect(describeWeather(1234).label, 'Météo inconnue');
    });

    test('gives advice only when the weather calls for it', () {
      const day = DayWeather(code: 0);
      const sunny = HourWeather(hour: 18, temperature: 22, code: 0);
      const rainy = HourWeather(
        hour: 18,
        temperature: 14,
        code: 63,
        precipitationProbability: 70,
      );
      const hot = HourWeather(hour: 15, temperature: 35, code: 0);
      const cold = HourWeather(hour: 7, temperature: 3, code: 0);

      expect(weatherAdvice(sunny, day), isNull);
      expect(weatherAdvice(rainy, day), contains('pluie'));
      expect(weatherAdvice(hot, day), contains('chaleur'));
      expect(weatherAdvice(cold, day), contains('froid'));
    });
  });

  group('OpenMeteoApi', () {
    test('finds a city and keeps its coordinates', () async {
      final server = _Server(_normal);
      final place = await server.api.findPlace('  Sfax ');

      expect(place.name, 'Sfax');
      expect(place.label, 'Sfax, Tunisie');
      expect(place.latitude, 34.74);
      expect(server.requests.single.url.queryParameters['name'], 'Sfax');
      expect(server.requests.single.url.queryParameters['language'], 'fr');
    });

    test('reports an unknown city and refuses a too-short name', () async {
      final server = _Server((_) => _json({}));

      await expectLater(
        server.api.findPlace('Zzzz'),
        throwsA(
          isA<WeatherApiException>().having(
            (error) => error.message,
            'message',
            contains('introuvable'),
          ),
        ),
      );
      await expectLater(
        server.api.findPlace('a'),
        throwsA(isA<WeatherApiException>()),
      );
      expect(server.requests, hasLength(1));
    });

    test('reads the hours of the requested day', () async {
      final server = _Server(_normal);
      final forecast = await server.api.forecast(
        defaultWeatherPlace,
        DateTime(2026, 11, 12, 18),
      );

      final query = server.requests.single.url.queryParameters;
      expect(query['start_date'], '2026-11-12');
      expect(query['end_date'], '2026-11-12');
      expect(query['timezone'], 'auto');
      expect(query['latitude'], '36.81897');
      expect(forecast.hours, hasLength(24));
      expect(forecast.at(18)!.temperature, 28);
      expect(forecast.at(18)!.precipitationProbability, 20);
      expect(forecast.at(18)!.windKmh, 12);
      expect(forecast.day.maxTemperature, 33.4);
      expect(forecast.day.minTemperature, 10.2);
      expect(forecast.day.code, 2);
    });

    test('refuses dates outside the forecast window without a request', () async {
      final server = _Server(_normal);

      await expectLater(
        server.api.forecast(defaultWeatherPlace, DateTime(2026, 11, 25)),
        throwsA(
          isA<WeatherApiException>().having(
            (error) => error.message,
            'message',
            contains('16 jours'),
          ),
        ),
      );
      await expectLater(
        server.api.forecast(defaultWeatherPlace, DateTime(2026, 6, 1)),
        throwsA(isA<WeatherApiException>()),
      );
      // Le dernier jour couvert (aujourd'hui + 15) reste accepté.
      await server.api.forecast(defaultWeatherPlace, DateTime(2026, 11, 24));
      expect(server.requests, hasLength(1));
    });

    test('shows the service reason when the request is rejected', () async {
      final server = _Server(
        (_) => _json({'error': true, 'reason': 'Date hors limites'}, 400),
      );

      await expectLater(
        server.api.forecast(defaultWeatherPlace, DateTime(2026, 11, 12)),
        throwsA(
          isA<WeatherApiException>().having(
            (error) => error.message,
            'message',
            contains('Date hors limites'),
          ),
        ),
      );
    });

    test('turns a network failure into a readable message', () async {
      final api = OpenMeteoApi(
        clock: () => _today,
        client: _ScriptedClient((_) async => throw http.ClientException('off')),
      );

      await expectLater(
        api.forecast(defaultWeatherPlace, DateTime(2026, 11, 12)),
        throwsA(
          isA<WeatherApiException>().having(
            (error) => error.message,
            'message',
            contains('connexion'),
          ),
        ),
      );
    });
  });

  group('WeatherCard', () {
    Future<void> show(
      WidgetTester tester,
      OpenMeteoApi api, {
      DateTime? date,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeatherCard(
                api: api,
                date: date ?? DateTime(2026, 11, 12),
                start: const TimeOfDay(hour: 18, minute: 0),
                end: const TimeOfDay(hour: 19, minute: 30),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the weather at the start and end of the seance', (
      tester,
    ) async {
      final server = _Server(_normal);
      await show(tester, server.api);

      expect(find.textContaining('Tunis, Tunisie'), findsOneWidget);
      expect(find.text('Début · 18:00'), findsOneWidget);
      expect(find.text('Fin · 19:30'), findsOneWidget);
      expect(find.text('28°'), findsOneWidget);
      // 19:30 est arrondi à 20 h.
      expect(find.text('30°'), findsOneWidget);
      expect(find.text('Plutôt dégagé'), findsNWidgets(2));
      expect(find.textContaining('Min 10°'), findsOneWidget);
      expect(find.textContaining('Max 33°'), findsOneWidget);
    });

    testWidgets('warns about rain', (tester) async {
      final server = _Server(
        (request) => _json(
          _forecastBody(request.url.queryParameters['start_date']!, rain: 80),
        ),
      );
      await show(tester, server.api);

      expect(find.textContaining('Risque de pluie'), findsOneWidget);
    });

    testWidgets('loads the new day when the date changes', (tester) async {
      final server = _Server(_normal);
      await show(tester, server.api);
      expect(server.requests, hasLength(1));

      await show(tester, server.api, date: DateTime(2026, 11, 14));

      expect(server.requests, hasLength(2));
      expect(
        server.requests.last.url.queryParameters['start_date'],
        '2026-11-14',
      );
    });

    testWidgets('explains a date that is too far away', (tester) async {
      final server = _Server(_normal);
      await show(tester, server.api, date: DateTime(2026, 12, 30));

      expect(find.textContaining('16 jours'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(server.requests, isEmpty);
    });

    testWidgets('changes the city and reloads', (tester) async {
      final server = _Server(_normal);
      await show(tester, server.api);

      await tester.tap(find.byTooltip('Changer de ville'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Sfax');
      await tester.tap(find.text('Rechercher'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sfax, Tunisie'), findsOneWidget);
      expect(server.requests.last.url.queryParameters['latitude'], '34.74');
    });

    testWidgets('keeps the current city when the new one is unknown', (
      tester,
    ) async {
      final server = _Server((request) {
        if (request.url.host == 'geocoding-api.open-meteo.com') {
          return _json({});
        }
        return _normal(request);
      });
      await show(tester, server.api);

      await tester.tap(find.byTooltip('Changer de ville'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Zzzz');
      await tester.tap(find.text('Rechercher'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ville introuvable'), findsOneWidget);
      expect(find.textContaining('Tunis, Tunisie'), findsOneWidget);
    });
  });
}

class _ScriptedClient extends http.BaseClient {
  _ScriptedClient(this._handler);

  final Future<http.Response> Function(http.Request request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request as http.Request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}
