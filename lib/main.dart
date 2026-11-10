
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/session_user.dart';
import 'core/services/app_services.dart';
import 'core/services/biometric_service.dart';
import 'core/utils/database_factory.dart';
import 'core/routes/app_routes.dart';
import 'core/widgets/resource_scope.dart';
import 'features/gestion_user/views/login_screen.dart';
import 'features/gestion_user/views/profile_screen.dart';
import 'features/gestion_user/repositories/user_repository.dart';
import 'features/groups/viewmodels/group_viewmodel.dart';
import 'features/groups/views/groups_list_page.dart';
import 'features/groups/widgets/join_requests_sheet.dart';
import 'features/home/views/home_screen.dart';
import 'features/meet/google_meet_auth.dart';
import 'features/notifications/seance_reminders.dart';
import 'features/resources/models/resource.dart';
import 'features/resources/views/resource_detail_page.dart';
import 'features/resources/views/resource_form_page.dart';
import 'features/resources/views/resources_page.dart';
import 'features/seances/seances_page.dart';
import 'features/seances/seances_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  initDatabaseFactory();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Google Sign-In ne s'initialise qu'une fois : GoogleMeetAuth le fait avec
  // l'identifiant client serveur dont Google Meet et Google Agenda ont besoin.
  await GoogleMeetAuth.instance.ensureInitialized();

  // Modules partagés (groupes ↔ ressources), liés à la session Firebase.
  initAppServices();

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
      routes: {
        AppRoutes.resourceDetail: (context) => ResourceDetailPage(
              id: ModalRoute.of(context)!.settings.arguments! as int,
            ),
        // Argument : la ressource à modifier, ou l'identifiant du groupe
        // présélectionné (partage depuis la page d'un groupe).
        AppRoutes.resourceForm: (context) {
          final arg = ModalRoute.of(context)!.settings.arguments;
          return ResourceFormPage(
            existing: arg is Resource ? arg : null,
            initialGroupId: arg is String ? arg : null,
          );
        },
      },
      builder: (context, child) => ResourceScope(
        notifier: resourceViewModel,
        child: child ?? const SizedBox.shrink(),
      ),
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

    SessionUser.role = localUser.role;

    // Profil public (nom, rôle, photo) visible par les membres des groupes.
    // Non bloquant : un échec réseau ne doit pas empêcher l'accès.
    SessionUser.syncProfile();

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
      SessionUser.role = '';

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

  // Séances de révision : stockage local, rappels sur le téléphone.
  final _seances = SeancesStore(reminders: seanceReminders);

  late final List<Widget> pages = [
    const HomeScreen(),
    const ResourcesPage(),
    // Module Groupes + Chat (même utilisateur Firebase que le reste).
    GroupsListPage(viewModel: groupViewModel, bottomInset: 84),
    SeancesPage(store: _seances),
    const ProfileScreen(),
  ];

  final List<(IconData, String)> tabs = const [
    (Icons.home, 'Accueil'),
    (Icons.menu_book, 'Ressources'),
    (Icons.groups, 'Groupes'),
    (Icons.calendar_month, 'Séances'),
    (Icons.person, 'Profil'),
  ];

  StreamSubscription<GroupNotice>? _noticeSub;

  @override
  void initState() {
    super.initState();
    // Notifications en temps réel : nouvelle demande d'adhésion reçue,
    // demande acceptée / refusée.
    _noticeSub = groupViewModel.notices.listen(_showNotice);
    _seances.load();
  }

  @override
  void dispose() {
    _noticeSub?.cancel();
    _seances.dispose();
    super.dispose();
  }

  void _showNotice(GroupNotice notice) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 6),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      content: Row(children: [
        const Icon(Icons.notifications_active_outlined, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(notice.message)),
      ]),
      action: notice.request == null
          ? null
          : SnackBarAction(
              label: 'Voir',
              onPressed: () => showJoinRequestsSheet(context, groupViewModel),
            ),
    ));
  }

  @override
  Widget build(BuildContext context) {
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
                        _TabIcon(
                          icon: tabs[i].$1,
                          color: active ? Colors.white : SM.muted,
                          // Onglet Groupes : nombre de demandes d'adhésion.
                          showRequests: i == 2,
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

/// Icône d'onglet, avec le nombre de demandes d'adhésion sur « Groupes ».
class _TabIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool showRequests;

  const _TabIcon({
    required this.icon,
    required this.color,
    this.showRequests = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = Icon(icon, size: 20, color: color);
    if (!showRequests) return base;
    return ListenableBuilder(
      listenable: groupViewModel,
      builder: (context, _) {
        final count = groupViewModel.pendingRequestCount;
        return Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          child: base,
        );
      },
    );
  }
}
