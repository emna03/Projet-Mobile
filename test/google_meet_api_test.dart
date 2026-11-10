import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:studymate/features/meet/google_meet_api.dart';
import 'package:studymate/features/meet/meet_space.dart';
import 'package:studymate/features/seances/models/seance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('meeting links only accept a Google Meet code', () {
    expect(
      meetingCodeFromLink('https://meet.google.com/abc-defg-hij'),
      'abc-defg-hij',
    );
    expect(isGoogleMeetLink('https://meet.google.com/new'), isFalse);
    expect(isGoogleMeetLink('https://example.com/abc-defg-hij'), isFalse);
    expect(isGoogleMeetLink('Visioconférence'), isFalse);
  });

  test('create, read, update and end a meeting space', () async {
    final requests = <http.Request>[];
    final api = GoogleMeetApi(
      accessToken: () async => 'token-1',
      onUnauthorized: (_) async {},
      client: _ScriptedClient((request) async {
        requests.add(request);
        return switch (request.method) {
          'POST' when request.url.path == '/v2/spaces' => _json({
            'name': 'spaces/jQCFfuBOdN5z',
            'meetingUri': 'https://meet.google.com/abc-defg-hij',
            'meetingCode': 'abc-defg-hij',
            'config': {'accessType': 'OPEN', 'entryPointAccess': 'ALL'},
          }),
          'GET' => _json({
            'name': 'spaces/jQCFfuBOdN5z',
            'meetingUri': 'https://meet.google.com/abc-defg-hij',
            'meetingCode': 'abc-defg-hij',
            'config': {'accessType': 'OPEN'},
            'activeConference': {'conferenceRecord': 'conferenceRecords/rec-1'},
          }),
          'PATCH' => _json({
            'name': 'spaces/jQCFfuBOdN5z',
            'meetingUri': 'https://meet.google.com/abc-defg-hij',
            'meetingCode': 'abc-defg-hij',
            'config': {'accessType': 'RESTRICTED'},
          }),
          'POST' => http.Response('{}', 200),
          _ => http.Response('{"error":{"message":"nope"}}', 404),
        };
      }),
    );

    final created = await api.createSpace();
    expect(created.name, 'spaces/jQCFfuBOdN5z');
    expect(created.meetingCode, 'abc-defg-hij');
    expect(created.access, MeetAccess.open);
    expect(requests.single.headers['Authorization'], 'Bearer token-1');
    expect(jsonDecode(requests.single.body), {
      'config': {'accessType': 'OPEN', 'entryPointAccess': 'ALL'},
    });

    final loaded = await api.getSpace('abc-defg-hij');
    expect(loaded.hasActiveConference, isTrue);
    expect(requests[1].url.path, '/v2/spaces/abc-defg-hij');

    final updated = await api.updateAccess(created.name, MeetAccess.restricted);
    expect(updated.access, MeetAccess.restricted);
    expect(requests[2].url.queryParameters['updateMask'], 'config.accessType');
    expect(jsonDecode(requests[2].body)['config'], {
      'accessType': 'RESTRICTED',
    });

    await api.endActiveConference(created.name);
    expect(requests[3].url.path, '/v2/spaces/jQCFfuBOdN5z:endActiveConference');
  });

  test('invitees of a restricted room can be listed, added and removed', () async {
    final requests = <http.Request>[];
    final api = GoogleMeetApi(
      accessToken: () async => 'token-1',
      onUnauthorized: (_) async {},
      client: _ScriptedClient((request) async {
        requests.add(request);
        final path = request.url.path;
        return switch (request.method) {
          'GET' when request.url.queryParameters['pageToken'] == null => _json({
            'members': [
              {
                'name': 'spaces/jQCFfuBOdN5z/members/m1',
                'email': 'sarah@gmail.com',
                'role': 'COHOST',
              },
            ],
            'nextPageToken': 'page-2',
          }),
          'GET' => _json({
            'members': [
              {
                'name': 'spaces/jQCFfuBOdN5z/members/m2',
                'email': 'yassine@gmail.com',
              },
            ],
          }),
          'POST' when path == '/v2/spaces/jQCFfuBOdN5z/members' => _json({
            'name': 'spaces/jQCFfuBOdN5z/members/m3',
            'email': 'ines@gmail.com',
          }),
          'DELETE' => http.Response('', 200),
          _ => http.Response('{"error":{"message":"nope"}}', 404),
        };
      }),
    );

    final members = await api.listMembers('spaces/jQCFfuBOdN5z');
    expect(members.map((member) => member.email), [
      'sarah@gmail.com',
      'yassine@gmail.com',
    ]);
    expect(members.first.isCohost, isTrue);
    expect(requests[1].url.queryParameters['pageToken'], 'page-2');

    final added = await api.addMember('jQCFfuBOdN5z', '  ines@gmail.com ');
    expect(added.name, 'spaces/jQCFfuBOdN5z/members/m3');
    expect(requests[2].url.path, '/v2/spaces/jQCFfuBOdN5z/members');
    expect(jsonDecode(requests[2].body), {'email': 'ines@gmail.com'});

    await api.removeMember(added.name);
    expect(requests[3].method, 'DELETE');
    expect(requests[3].url.path, '/v2/spaces/jQCFfuBOdN5z/members/m3');

    await expectLater(
      api.addMember('jQCFfuBOdN5z', 'pas-un-email'),
      throwsA(isA<MeetApiException>()),
    );
    await expectLater(
      api.removeMember('spaces/jQCFfuBOdN5z'),
      throwsA(isA<MeetApiException>()),
    );
    expect(requests, hasLength(4));
  });

  test('an API error uses the Google Meet message and retries once', () async {
    var calls = 0;
    final api = GoogleMeetApi(
      accessToken: () async => calls == 0 ? 'expired' : 'fresh',
      onUnauthorized: (token) async => expect(token, 'expired'),
      client: _ScriptedClient((request) async {
        calls++;
        if (request.headers['Authorization'] == 'Bearer expired') {
          return http.Response('{"error":{"message":"Jeton expiré"}}', 401);
        }
        return http.Response(
          '{"error":{"message":"Meet API has not been used"}}',
          403,
        );
      }),
    );

    await expectLater(
      api.createSpace(),
      throwsA(
        isA<MeetApiException>().having(
          (error) => error.message,
          'message',
          'Meet API has not been used',
        ),
      ),
    );
  });

  test('a seance keeps its Meet space in the database map', () {
    final seance = Seance(
      id: 'flutter',
      ownerId: 'user-ab',
      subject: 'Flutter',
      title: 'Révisions Flutter & Dart',
      host: 'Alex Benali',
      date: DateTime(2026, 10, 11),
      start: const TimeOfDay(hour: 17, minute: 0),
      end: const TimeOfDay(hour: 18, minute: 30),
      format: SessionFormat.online,
      place: 'https://meet.google.com/abc-defg-hij',
      seatsLeft: 6,
      meetSpaceName: 'spaces/jQCFfuBOdN5z',
      meetCode: 'abc-defg-hij',
      meetAccess: 'OPEN',
    );

    final restored = Seance.fromMap(seance.toMap());

    expect(restored.meetSpaceName, 'spaces/jQCFfuBOdN5z');
    expect(restored.meetCode, 'abc-defg-hij');
    expect(restored.meetAccess, 'OPEN');
    expect(restored.place, 'https://meet.google.com/abc-defg-hij');
  });
}

http.Response _json(Map<String, Object?> body) {
  return http.Response(jsonEncode(body), 200);
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
