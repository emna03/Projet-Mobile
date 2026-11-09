/// Accès d'une salle créée avec l'API Google Meet.
enum MeetAccess { open, trusted, restricted }

extension MeetAccessDetails on MeetAccess {
  String get apiValue => switch (this) {
    MeetAccess.open => 'OPEN',
    MeetAccess.trusted => 'TRUSTED',
    MeetAccess.restricted => 'RESTRICTED',
  };

  String get label => switch (this) {
    MeetAccess.open => 'Ouvert',
    MeetAccess.trusted => 'Organisation',
    MeetAccess.restricted => 'Invitation',
  };

  String get hint => switch (this) {
    MeetAccess.open => 'Toute personne avec le lien peut rejoindre.',
    MeetAccess.trusted => 'Réservé aux comptes de ton organisation.',
    MeetAccess.restricted => 'Seules les personnes invitées peuvent entrer.',
  };

  static MeetAccess parse(
    String? value, {
    MeetAccess fallback = MeetAccess.open,
  }) {
    return switch (value) {
      'OPEN' => MeetAccess.open,
      'TRUSTED' => MeetAccess.trusted,
      'RESTRICTED' => MeetAccess.restricted,
      _ => fallback,
    };
  }
}

/// Salle renvoyée par `spaces.create`, `spaces.get` ou `spaces.patch`.
class MeetSpace {
  const MeetSpace({
    required this.name,
    required this.meetingUri,
    required this.meetingCode,
    required this.access,
    this.conferenceRecord,
  });

  /// Nom de ressource, par exemple `spaces/jQCFfuBOdN5z`.
  final String name;
  final String meetingUri;
  final String meetingCode;
  final MeetAccess access;

  /// Renseigné seulement pendant une réunion active.
  final String? conferenceRecord;

  bool get hasActiveConference =>
      conferenceRecord != null && conferenceRecord!.isNotEmpty;
}

/// Personne autorisée à entrer dans une salle `RESTRICTED`.
class MeetMember {
  const MeetMember({required this.name, required this.email, this.role});

  /// Nom de ressource, par exemple `spaces/jQCFfuBOdN5z/members/abc123`.
  final String name;
  final String email;
  final String? role;

  bool get isCohost => role == 'COHOST';
}

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

bool isValidInviteeEmail(String value) => _emailPattern.hasMatch(value.trim());

class MeetApiException implements Exception {
  const MeetApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

final _meetCodePattern = RegExp(r'^[A-Za-z0-9-]{3,128}$');

/// Code Meet d'une URL `https://meet.google.com/xxx-yyyy-zzz`, sinon null.
String? meetingCodeFromLink(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme != 'https' || uri.host != 'meet.google.com') {
    return null;
  }
  if (uri.pathSegments.length != 1) return null;
  final code = uri.pathSegments.single;
  if (code == 'new' || code == 'lookup' || !_meetCodePattern.hasMatch(code)) {
    return null;
  }
  return code;
}

bool isGoogleMeetLink(String value) => meetingCodeFromLink(value) != null;
