/// Abstraction légère pour récupérer l'UID Firebase sans coupler le module
/// au reste de l'app (AuthGate / gestion_user).
///
/// Fallback `local-demo` si aucun provider (tests / démo isolée).
/// Depuis Home : injecter `() => FirebaseAuth.instance.currentUser?.uid`.
typedef QuizUserIdProvider = Future<String?> Function();

class QuizUserContext {
  QuizUserContext({QuizUserIdProvider? provider}) : _provider = provider;

  final QuizUserIdProvider? _provider;

  static const localDemoUserId = 'local-demo';

  Future<String> currentUserId() async {
    final uid = await _provider?.call();
    if (uid == null || uid.trim().isEmpty) {
      return localDemoUserId;
    }
    return uid.trim();
  }
}
