import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:studymate/features/meet/google_meet_auth.dart';
import 'package:studymate/features/meet/meet_space.dart';

typedef AccessTokenProvider = Future<String> Function();
typedef UnauthorizedHandler = Future<void> Function(String token);

/// Client de l'API Google Meet v2 : création, lecture, mise à jour et fin
/// d'une conférence sur la ressource `spaces`.
class GoogleMeetApi {
  GoogleMeetApi({
    http.Client? client,
    AccessTokenProvider? accessToken,
    UnauthorizedHandler? onUnauthorized,
  }) : _client = client ?? http.Client(),
       _accessToken = accessToken ?? GoogleMeetAuth.instance.accessToken,
       _onUnauthorized = onUnauthorized ?? GoogleMeetAuth.instance.invalidate,
       _ownsClient = client == null;

  static const _root = 'https://meet.googleapis.com/v2';

  final http.Client _client;
  final AccessTokenProvider _accessToken;
  final UnauthorizedHandler _onUnauthorized;
  final bool _ownsClient;

  Future<MeetSpace> createSpace({MeetAccess access = MeetAccess.open}) {
    return _send(
      (token) => _client.post(
        Uri.parse('$_root/spaces'),
        headers: _jsonHeaders(token),
        body: jsonEncode({
          'config': {'accessType': access.apiValue, 'entryPointAccess': 'ALL'},
        }),
      ),
      (body) => _parseSpace(body, fallback: access),
    );
  }

  Future<MeetSpace> getSpace(String nameOrCode) {
    return _send(
      (token) => _client.get(
        Uri.parse('$_root/${_resource(nameOrCode)}'),
        headers: _headers(token),
      ),
      _parseSpace,
    );
  }

  Future<MeetSpace> updateAccess(String spaceName, MeetAccess access) {
    final name = _resource(spaceName);
    final uri = Uri.parse('$_root/$name')
        .replace(queryParameters: const {'updateMask': 'config.accessType'});
    return _send(
      (token) => _client.patch(
        uri,
        headers: _jsonHeaders(token),
        body: jsonEncode({
          'name': name,
          'config': {'accessType': access.apiValue},
        }),
      ),
      (body) => _parseSpace(body, fallback: access),
    );
  }

  Future<void> endActiveConference(String spaceName) {
    final name = _resource(spaceName);
    return _send(
      (token) => _client.post(
        Uri.parse('$_root/$name:endActiveConference'),
        headers: _jsonHeaders(token),
        body: '{}',
      ),
      (_) {},
    );
  }

  /// Personnes invitées dans une salle `RESTRICTED`.
  Future<List<MeetMember>> listMembers(String spaceName) async {
    final name = _resource(spaceName);
    final members = <MeetMember>[];
    String? pageToken;
    do {
      final uri = Uri.parse('$_root/$name/members').replace(
        queryParameters: {
          'pageSize': '100',
          if (pageToken != null) 'pageToken': pageToken,
        },
      );
      final page = await _send<Map<String, Object?>>(
        (token) => _client.get(uri, headers: _headers(token)),
        (body) => body,
      );
      final entries = page['members'];
      if (entries is List) {
        for (final entry in entries) {
          if (entry is Map) {
            final member = _parseMember(Map<String, Object?>.from(entry));
            if (member != null) members.add(member);
          }
        }
      }
      final next = page['nextPageToken'];
      pageToken = next is String && next.isNotEmpty ? next : null;
    } while (pageToken != null);
    return members;
  }

  Future<MeetMember> addMember(String spaceName, String email) async {
    final name = _resource(spaceName);
    final address = email.trim();
    if (!isValidInviteeEmail(address)) {
      throw const MeetApiException('Adresse e-mail invalide.');
    }
    return await _send(
      (token) => _client.post(
        Uri.parse('$_root/$name/members'),
        headers: _jsonHeaders(token),
        body: jsonEncode({'email': address}),
      ),
      (body) =>
          _parseMember(body, fallbackEmail: address) ??
          (throw const MeetApiException(
            'La réponse Google Meet est incomplète.',
          )),
    );
  }

  Future<void> removeMember(String memberName) async {
    final name = memberName.trim();
    if (!name.startsWith('spaces/') || !name.contains('/members/')) {
      throw const MeetApiException('Invité Google Meet inconnu.');
    }
    await _send(
      (token) =>
          _client.delete(Uri.parse('$_root/$name'), headers: _headers(token)),
      (_) {},
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  MeetMember? _parseMember(Map<String, Object?> body, {String? fallbackEmail}) {
    final name = body['name'];
    if (name is! String || name.isEmpty) return null;
    final email = body['email'];
    final user = body['user'];
    final label = email is String && email.isNotEmpty
        ? email
        : (fallbackEmail ?? (user is String ? user : ''));
    if (label.isEmpty) return null;
    final role = body['role'];
    return MeetMember(
      name: name,
      email: label,
      role: role is String ? role : null,
    );
  }

  Future<T> _send<T>(
    Future<http.Response> Function(String token) send,
    T Function(Map<String, Object?> body) parse,
  ) async {
    final token = await _accessToken();
    var response = await send(token);
    if (response.statusCode == 401) {
      await _onUnauthorized(token);
      final refreshed = await _accessToken();
      response = await send(refreshed);
    }
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MeetApiException(_errorMessage(body, response.statusCode));
    }
    return parse(body);
  }

  Map<String, String> _headers(String token) {
    return {'Authorization': 'Bearer $token', 'Accept': 'application/json'};
  }

  Map<String, String> _jsonHeaders(String token) {
    return {..._headers(token), 'Content-Type': 'application/json'};
  }

  String _resource(String nameOrCode) {
    final value = nameOrCode.trim();
    if (value.isEmpty) {
      throw const MeetApiException('Identifiant de salle Meet manquant.');
    }
    if (value.startsWith('spaces/')) return value;
    return 'spaces/$value';
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
    throw MeetApiException('Google Meet a répondu ${response.statusCode}.');
  }

  String _errorMessage(Map<String, Object?> body, int status) {
    final error = body['error'];
    if (error is Map) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return 'Google Meet a répondu $status.';
  }

  MeetSpace _parseSpace(
    Map<String, Object?> body, {
    MeetAccess fallback = MeetAccess.open,
  }) {
    final name = body['name'];
    final meetingUri = body['meetingUri'];
    final meetingCode = body['meetingCode'];
    if (name is! String || meetingUri is! String || meetingCode is! String) {
      throw const MeetApiException('La réponse Google Meet est incomplète.');
    }

    String? accessType;
    final config = body['config'];
    if (config is Map && config['accessType'] is String) {
      accessType = config['accessType'] as String;
    }

    String? conferenceRecord;
    final active = body['activeConference'];
    if (active is Map && active['conferenceRecord'] is String) {
      conferenceRecord = active['conferenceRecord'] as String;
    }

    return MeetSpace(
      name: name,
      meetingUri: meetingUri,
      meetingCode: meetingCode,
      access: MeetAccessDetails.parse(accessType, fallback: fallback),
      conferenceRecord: conferenceRecord,
    );
  }
}

final googleMeetApi = GoogleMeetApi();
