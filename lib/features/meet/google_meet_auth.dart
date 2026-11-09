import 'package:google_sign_in/google_sign_in.dart';
import 'package:studymate/features/meet/google_meet_config.dart';
import 'package:studymate/features/meet/meet_space.dart';

/// Connexion Google avec le scope qui autorise la création de salles Meet.
class GoogleMeetAuth {
  GoogleMeetAuth._();

  static final instance = GoogleMeetAuth._();

  static const scopes = <String>[
    'https://www.googleapis.com/auth/meetings.space.created',
  ];

  Future<void>? _pending;

  Future<void> ensureInitialized() {
    return _pending ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: GoogleMeetConfig.serverClientId,
      );
    } catch (error) {
      _pending = null;
      rethrow;
    }
  }

  /// Jeton OAuth pour [requested] (Meet par défaut). Le même compte Google
  /// sert aux autres API, par exemple Google Agenda.
  Future<String> accessToken({List<String>? requested}) async {
    final needed = requested ?? scopes;
    try {
      await ensureInitialized();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const MeetApiException(
          'La connexion Google n\'est pas disponible sur cet appareil.',
        );
      }

      GoogleSignInAccount? account;
      final lightweight = GoogleSignIn.instance
          .attemptLightweightAuthentication();
      if (lightweight != null) {
        try {
          account = await lightweight;
        } on GoogleSignInException {
          account = null;
        }
      }
      account ??= await GoogleSignIn.instance.authenticate(scopeHint: needed);

      final authorization =
          await account.authorizationClient.authorizationForScopes(needed) ??
          await account.authorizationClient.authorizeScopes(needed);
      if (authorization.accessToken.isEmpty) {
        throw const MeetApiException('Google n\'a pas renvoyé de jeton.');
      }
      return authorization.accessToken;
    } on MeetApiException {
      rethrow;
    } on GoogleSignInException catch (error) {
      throw MeetApiException(_message(error));
    } catch (error) {
      throw MeetApiException('Connexion Google impossible. $error');
    }
  }

  Future<void> invalidate(String token) async {
    try {
      await ensureInitialized();
      await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(
        accessToken: token,
      );
    } catch (_) {
      // Le prochain essai redemandera l'autorisation.
    }
  }

  String _message(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => 'Connexion Google annulée.',
      GoogleSignInExceptionCode.interrupted => 'Connexion Google interrompue.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Impossible d\'afficher la connexion Google.',
      GoogleSignInExceptionCode.userMismatch =>
        'Le compte Google ne correspond pas à la session en cours.',
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Configure un client OAuth Android pour com.example.studymate et active l\'API Google Meet. ${error.description ?? ''}'
            .trim(),
      _ => error.description ?? 'Connexion Google impossible.',
    };
  }
}
