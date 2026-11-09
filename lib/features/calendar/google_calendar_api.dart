import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:studymate/features/meet/google_meet_auth.dart';
import 'package:studymate/features/meet/meet_space.dart';
import 'package:studymate/features/seances/models/seance.dart';

/// Niveau d'accès qui permet de créer et modifier des événements.
const calendarScopes = <String>[
  'https://www.googleapis.com/auth/calendar.events',
];

typedef CalendarTokenProvider = Future<String> Function();
typedef CalendarUnauthorizedHandler = Future<void> Function(String token);

class CalendarApiException implements Exception {
  const CalendarApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Début et fin réels d'une séance. Une séance qui finit "avant" son début
/// passe minuit : elle se termine le lendemain.
({DateTime start, DateTime end}) seanceInterval(Seance seance) {
  final day = seance.date;
  final start = DateTime(
    day.year,
    day.month,
    day.day,
    seance.start.hour,
    seance.start.minute,
  );
  var end = DateTime(
    day.year,
    day.month,
    day.day,
    seance.end.hour,
    seance.end.minute,
  );
  if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
  return (start: start, end: end);
}

/// Événement Google Agenda décrivant [seance].
Map<String, Object?> calendarEventBody(Seance seance) {
  final interval = seanceInterval(seance);
  final place = seance.place.trim();
  final lines = <String>[
    'Séance de révision StudyMate',
    'Matière : ${seance.subject}',
    'Animateur : ${seance.host}',
    if (place.isNotEmpty)
      seance.isOnline ? 'Lien : $place' : 'Salle : $place',
  ];
  return {
    'summary': seance.title,
    'description': lines.join('\n'),
    if (place.isNotEmpty) 'location': place,
    'start': {'dateTime': interval.start.toUtc().toIso8601String()},
    'end': {'dateTime': interval.end.toUtc().toIso8601String()},
    // Réactive un événement supprimé depuis Google Agenda.
    'status': 'confirmed',
    'reminders': {
      'useDefault': false,
      'overrides': [
        {'method': 'popup', 'minutes': 30},
      ],
    },
    'extendedProperties': {
      'private': {'studymateSeanceId': seance.id},
    },
  };
}

/// Client de l'API Google Agenda v3 sur le calendrier principal.
class GoogleCalendarApi {
  GoogleCalendarApi({
    http.Client? client,
    CalendarTokenProvider? accessToken,
    CalendarUnauthorizedHandler? onUnauthorized,
  }) : _client = client ?? http.Client(),
       _accessToken = accessToken ?? _defaultToken,
       _onUnauthorized = onUnauthorized ?? GoogleMeetAuth.instance.invalidate,
       _ownsClient = client == null;

  static const _events =
      'https://www.googleapis.com/calendar/v3/calendars/primary/events';

  final http.Client _client;
  final CalendarTokenProvider _accessToken;
  final CalendarUnauthorizedHandler _onUnauthorized;
  final bool _ownsClient;

  static Future<String> _defaultToken() async {
    try {
      return await GoogleMeetAuth.instance.accessToken(
        requested: calendarScopes,
      );
    } on MeetApiException catch (error) {
      throw CalendarApiException(error.message);
    }
  }

  /// Crée l'événement de [seance], ou met à jour celui qui existe déjà.
  ///
  /// [eventId] est l'identifiant mémorisé localement. S'il est inconnu ou si
  /// l'événement a disparu, on cherche d'abord un événement de cette séance
  /// pour ne pas créer de doublon. Renvoie l'identifiant à mémoriser.
  Future<String> upsertSeance(Seance seance, {String? eventId}) async {
    final body = jsonEncode(calendarEventBody(seance));
    var id = eventId != null && eventId.isNotEmpty ? eventId : null;
    id ??= await _findBySeance(seance.id);

    if (id != null) {
      final updated = await _send(
        (token) => _client.patch(
          Uri.parse('$_events/${Uri.encodeComponent(id!)}'),
          headers: _jsonHeaders(token),
          body: body,
        ),
        tolerated: const {404, 410},
      );
      if (updated != null) return _idOf(updated);
    }

    final created = await _send(
      (token) => _client.post(
        Uri.parse(_events),
        headers: _jsonHeaders(token),
        body: body,
      ),
    );
    return _idOf(created!);
  }

  /// Supprime l'événement. Un événement déjà supprimé n'est pas une erreur.
  Future<void> deleteEvent(String eventId) async {
    final id = eventId.trim();
    if (id.isEmpty) return;
    await _send(
      (token) => _client.delete(
        Uri.parse('$_events/${Uri.encodeComponent(id)}'),
        headers: _headers(token),
      ),
      tolerated: const {404, 410},
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<String?> _findBySeance(String seanceId) async {
    final uri = Uri.parse(_events).replace(
      queryParameters: {
        'privateExtendedProperty': 'studymateSeanceId=$seanceId',
        'maxResults': '1',
      },
    );
    final page = await _send(
      (token) => _client.get(uri, headers: _headers(token)),
    );
    final items = page?['items'];
    if (items is List && items.isNotEmpty && items.first is Map) {
      final id = (items.first as Map)['id'];
      if (id is String && id.isNotEmpty) return id;
    }
    return null;
  }

  /// Renvoie le corps décodé, ou null si le statut fait partie de [tolerated].
  Future<Map<String, Object?>?> _send(
    Future<http.Response> Function(String token) send, {
    Set<int> tolerated = const {},
  }) async {
    final token = await _accessToken();
    var response = await send(token);
    if (response.statusCode == 401) {
      await _onUnauthorized(token);
      response = await send(await _accessToken());
    }
    if (tolerated.contains(response.statusCode)) return null;
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CalendarApiException(_errorMessage(body, response.statusCode));
    }
    return body;
  }

  Map<String, String> _headers(String token) {
    return {'Authorization': 'Bearer $token', 'Accept': 'application/json'};
  }

  Map<String, String> _jsonHeaders(String token) {
    return {..._headers(token), 'Content-Type': 'application/json'};
  }

  Map<String, Object?> _decode(http.Response response) {
    if (response.body.isEmpty) return const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } catch (_) {
      // Le message d'erreur ci-dessous couvre une réponse non JSON.
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return const {};
    }
    throw CalendarApiException('Google Agenda a répondu ${response.statusCode}.');
  }

  String _errorMessage(Map<String, Object?> body, int status) {
    final error = body['error'];
    if (error is Map) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return 'Google Agenda a répondu $status.';
  }

  String _idOf(Map<String, Object?> event) {
    final id = event['id'];
    if (id is! String || id.isEmpty) {
      throw const CalendarApiException(
        'La réponse Google Agenda est incomplète.',
      );
    }
    return id;
  }
}

final googleCalendarApi = GoogleCalendarApi();
