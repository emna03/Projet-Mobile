import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Résultat détaillé d'une tentative d'authentification biométrique.
class BiometricResult {
  final bool success;
  final String? message;

  const BiometricResult.ok()
      : success = true,
        message = null;

  const BiometricResult.fail(this.message) : success = false;
}

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String _key(String uid) => 'biometric_enabled_$uid';

  /// Disponibilité "large" : sur Xiaomi (HyperOS/MIUI), getAvailableBiometrics()
  /// peut renvoyer une liste vide alors que l'empreinte fonctionne.
  /// On ne bloque donc pas sur cette liste : c'est authenticateWithResult()
  /// qui renvoie la vraie cause si aucune empreinte n'est enrôlée.
  Future<bool> isBiometricAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final biometrics = await _auth.getAvailableBiometrics();
      debugPrint('Biometrics: supported=$supported, '
          'canCheck=$canCheck, available=$biometrics');
      return supported;
    } catch (e) {
      debugPrint('Biometric availability error: $e');
      return false;
    }
  }

  /// Version détaillée : renvoie la vraie cause de l'échec.
  Future<BiometricResult> authenticateWithResult() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Vérifiez votre empreinte pour accéder à StudyMate',
        biometricOnly: true,
      );
      return ok
          ? const BiometricResult.ok()
          : const BiometricResult.fail('Empreinte non reconnue.');
    } on LocalAuthException catch (e) {
      debugPrint('Authentication error: ${e.code.name}');
      switch (e.code.name) {
        case 'userCanceled':
        case 'systemCanceled':
          return const BiometricResult.fail('Vérification annulée.');
        case 'noBiometricsEnrolled':
          return const BiometricResult.fail(
              'Aucune empreinte enregistrée sur ce téléphone.');
        case 'noBiometricHardware':
          return const BiometricResult.fail(
              'Ce téléphone ne dispose pas de lecteur biométrique.');
        case 'temporaryLockout':
          return const BiometricResult.fail(
              'Trop de tentatives. Réessayez dans quelques instants.');
        case 'biometricLockout':
          return const BiometricResult.fail(
              'Biométrie verrouillée. Déverrouillez le téléphone avec votre code.');
        default:
          return BiometricResult.fail('Erreur biométrique (${e.code.name}).');
      }
    } catch (e) {
      debugPrint('Authentication error: $e');
      return BiometricResult.fail('Erreur biométrique : $e');
    }
  }

  /// Compatible avec le code existant (ex. LoginScreen).
  Future<bool> authenticate() async =>
      (await authenticateWithResult()).success;

  Future<void> enableForAccount(String uid) =>
      _storage.write(key: _key(uid), value: 'true');

  Future<void> disableForAccount(String uid) =>
      _storage.delete(key: _key(uid));

  Future<bool> isEnabledForAccount(String uid) async =>
      await _storage.read(key: _key(uid)) == 'true';
}