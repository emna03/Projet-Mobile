
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/biometric_service.dart';
import 'features/gestion_user/views/login_screen.dart';
import 'features/gestion_user/views/profile_screen.dart';
import 'features/gestion_user/repositories/user_repository.dart';
import 'features/home/views/home_screen.dart';
import 'features/seances/seances_page.dart';
import 'features/seances/seances_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await GoogleSignIn.instance.initialize();

  runApp(const StudyMateApp());
}

class StudyMateApp extends StatelessWidget {
  const StudyMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyMate',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AuthGate(),
    );
  }
}

// ============================================================
// AUTH GATE + VERROUILLAGE BIOMÉTRIQUE
// ============================================================

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate>
    with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final BiometricService _biometricService =
      BiometricService();

  bool _isLoading = true;
  bool _hasSession = false;
  bool _biometricEnabled = false;
  bool _isUnlocked = false;
  bool _isAuthenticating = false;

  bool _shouldUnlockOnResume = false;
  bool _appIsInBackground = false;
  bool _backgroundCheckInProgress = false;
  bool _resumePending = false;

  String? _biometricMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initializeSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ------------------------------------------------------------
  // INITIALISATION DE LA SESSION
  // ------------------------------------------------------------

  Future<void> _initializeSession() async {
    try {
      final validSession = await _checkSession();

      if (!mounted) return;

      if (!validSession) {
        setState(() {
          _hasSession = false;
          _isUnlocked = false;
          _isLoading = false;
        });
        return;
      }

      final uid = _auth.currentUser!.uid;

      final enabled =
          await _biometricService.isEnabledForAccount(uid);

      if (!mounted) return;

      setState(() {
        _hasSession = true;
        _biometricEnabled = enabled;

        // Sans biométrie : accès automatique.
        // Avec biométrie : écran verrouillé.
        _isUnlocked = !enabled;
      });

      if (enabled) {
        await _authenticateToUnlock();
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Session initialization error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasSession = false;
      });
    }
  }

  // ------------------------------------------------------------
  // VÉRIFICATION FIREBASE + SQLITE
  // ------------------------------------------------------------

  Future<bool> _checkSession() async {
    User? user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    await user.reload();
    user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    // Vérification de l'email.
    if (!user.emailVerified) {
      await _auth.signOut();
      return false;
    }

    final email = user.email;

    if (email == null || email.isEmpty) {
      await _auth.signOut();
      return false;
    }

    // Vérification du profil local SQLite.
    final userRepository = UserRepository();

    final localUser =
        await userRepository.getUserByEmail(email);

    if (localUser == null) {
      await _auth.signOut();
      return false;
    }

    return true;
  }

  // ------------------------------------------------------------
  // AUTHENTIFICATION BIOMÉTRIQUE
  // ------------------------------------------------------------

  Future<void> _authenticateToUnlock() async {
    if (_isAuthenticating) return;
    if (_auth.currentUser == null) return;

    setState(() {
      _isAuthenticating = true;
      _biometricMessage = null;
    });

    try {
      final result =
          await _biometricService.authenticateWithResult();

      if (!mounted) return;

      setState(() {
        _isUnlocked = result.success;

        _biometricMessage = result.success
            ? null
            : result.message ?? 'Vérification échouée.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isUnlocked = false;
        _biometricMessage =
            'Erreur lors de la vérification biométrique.';
      });

      debugPrint('Biometric unlock error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // GESTION DU CYCLE DE VIE DE L'APPLICATION
  // ------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_hasSession || _isLoading || _isAuthenticating) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_appIsInBackground) return;

      _appIsInBackground = true;

      _handleAppBackground();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _appIsInBackground = false;

      if (_backgroundCheckInProgress) {
        _resumePending = true;
        return;
      }

      _unlockAfterResume();
    }
  }

  // ------------------------------------------------------------
  // ACTION QUAND L'APPLICATION PASSE EN ARRIÈRE-PLAN
  // ------------------------------------------------------------

  Future<void> _handleAppBackground() async {
    if (_backgroundCheckInProgress) return;

    _backgroundCheckInProgress = true;

    try {
      final uid = _auth.currentUser?.uid;

      if (uid == null) return;

      final enabled =
          await _biometricService.isEnabledForAccount(uid);

      if (!mounted) return;

      if (!enabled) {
        // Sans empreinte :
        // conserver la session Firebase.
        // Ne pas déconnecter l'utilisateur.
        setState(() {
          _biometricEnabled = false;
          _isUnlocked = true;
          _shouldUnlockOnResume = false;
          _biometricMessage = null;
        });

        return;
      }

      // Avec empreinte :
      // verrouiller l'application.
      setState(() {
        _biometricEnabled = true;
        _isUnlocked = false;
        _shouldUnlockOnResume = true;
        _biometricMessage = null;
      });
    } catch (e) {
      debugPrint('Background handling error: $e');
    } finally {
      _backgroundCheckInProgress = false;

      final shouldResume =
          _resumePending || !_appIsInBackground;

      _resumePending = false;

      if (shouldResume &&
          mounted &&
          _hasSession &&
          _shouldUnlockOnResume) {
        await _unlockAfterResume();
      }
    }
  }

  // ------------------------------------------------------------
  // RETOUR DANS L'APPLICATION
  // ------------------------------------------------------------

  Future<void> _unlockAfterResume() async {
    if (_shouldUnlockOnResume == false ||
        _isAuthenticating) {
      return;
    }

    _shouldUnlockOnResume = false;

    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      if (!mounted) return;

      setState(() {
        _hasSession = false;
        _isUnlocked = false;
      });

      return;
    }

    final enabled =
        await _biometricService.isEnabledForAccount(uid);

    if (!mounted) return;

    if (!enabled) {
      // Si l'utilisateur a désactivé l'empreinte :
      // accès automatique sans déconnexion.
      setState(() {
        _biometricEnabled = false;
        _isUnlocked = true;
        _biometricMessage = null;
      });

      return;
    }

    // Si l'empreinte est activée :
    // demander une nouvelle authentification.
    setState(() {
      _biometricEnabled = true;
      _isUnlocked = false;
    });

    await _authenticateToUnlock();
  }

  // ------------------------------------------------------------
  // DÉCONNEXION DEPUIS L'ÉCRAN VERROUILLÉ
  // ------------------------------------------------------------

  Future<void> _logoutFromLockScreen() async {
    try {
      await _auth.signOut();

      if (!mounted) return;

      setState(() {
        _hasSession = false;
        _isUnlocked = false;
        _biometricEnabled = false;
        _shouldUnlockOnResume = false;
        _biometricMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _biometricMessage =
            'Impossible de se déconnecter. Réessaie.';
      });
    }
  }

  // ------------------------------------------------------------
  // INTERFACE
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_hasSession) {
      return const LoginScreen();
    }

    if (_biometricEnabled && !_isUnlocked) {
      return PopScope(
        canPop: false,
        child: _buildLockScreen(),
      );
    }

    return const Shell();
  }

  // ------------------------------------------------------------
  // ÉCRAN DE VERROUILLAGE
  // ------------------------------------------------------------

  Widget _buildLockScreen() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: SM.primarySoft,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.fingerprint,
                    color: SM.primary,
                    size: 60,
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  'StudyMate est verrouillé',
                  style: SM.h(23),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 10),

                Text(
                  'Utilise ton empreinte digitale pour '
                  'accéder à ton compte.',
                  style: SM.b(14, color: SM.muted),
                  textAlign: TextAlign.center,
                ),

                if (_biometricMessage != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _biometricMessage!,
                    textAlign: TextAlign.center,
                    style: SM.b(13, color: SM.danger),
                  ),
                ],

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isAuthenticating
                        ? null
                        : _authenticateToUnlock,
                    icon: _isAuthenticating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.fingerprint),
                    label: Text(
                      _isAuthenticating
                          ? 'Vérification...'
                          : 'Déverrouiller',
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: _isAuthenticating
                      ? null
                      : _logoutFromLockScreen,
                  child: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// NAVIGATION PRINCIPALE
// ============================================================

class Shell extends StatefulWidget {
  final int initial;

  const Shell({
    super.key,
    this.initial = 0,
  });

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late int index = widget.initial;
  final _seances = SeancesStore();

  @override
  void initState() {
    super.initState();
    _seances.load();
  }

  @override
  void dispose() {
    _seances.dispose();
    super.dispose();
  }

  static const tabs = <(IconData, String)>[
    (Icons.home, 'Accueil'),
    (Icons.menu_book, 'Ressources'),
    (Icons.groups, 'Groupes'),
    (Icons.calendar_month, 'Séances'),
    (Icons.person, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeScreen(),
      const Center(child: Text('Ressources')),
      const Center(child: Text('Groupes')),
      SeancesPage(store: _seances),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: pages[index],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: SM.shadow,
          ),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final bool active = i == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      index = i;
                    });
                  },
                  child: AnimatedContainer(
                    duration: SM.anim,
                    height: 56,
                    decoration: BoxDecoration(
                      color: active
                          ? SM.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tabs[i].$1,
                          size: 20,
                          color: active
                              ? Colors.white
                              : SM.muted,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tabs[i].$2,
                          style: SM.b(
                            10,
                            color: active
                                ? Colors.white
                                : SM.muted,
                            w: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
