
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../repositories/user_repository.dart';
import '../../../main.dart';
import '../../../core/theme/app_theme.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final UserRepository _userRepository = UserRepository();

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? emailError;
  String? passwordError;

  bool isLoggingIn = false;
  bool obscurePassword = true;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ========================================
  // VALIDATION
  // ========================================

  bool _isEmailValid(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(email);
  }

  bool _validate() {
    final email = emailController.text.trim();
    final password = passwordController.text;

    String? eError;
    String? pError;

    if (email.isEmpty) {
      eError = 'Veuillez saisir votre email.';
    } else if (!_isEmailValid(email)) {
      eError = 'Adresse email invalide.';
    }

    if (password.isEmpty) {
      pError = 'Veuillez saisir votre mot de passe.';
    } else if (password.length < 8) {
      pError =
          'Le mot de passe doit contenir au moins 8 caractères.';
    }

    setState(() {
      emailError = eError;
      passwordError = pError;
    });

    return eError == null && pError == null;
  }

  // ========================================
  // CONNEXION EMAIL / MOT DE PASSE
  // ========================================

  Future<void> _login() async {
    if (isLoggingIn || !_validate()) return;

    setState(() => isLoggingIn = true);

    try {
      final credential =
          await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim().toLowerCase(),
        password: passwordController.text,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        _showMessage('Impossible de récupérer le compte.');
        return;
      }

      await firebaseUser.reload();

      final refreshedUser = _auth.currentUser;

      if (refreshedUser == null) {
        _showMessage('Session introuvable. Réessaie.');
        return;
      }

      if (!refreshedUser.emailVerified) {
        try {
          await refreshedUser.sendEmailVerification();

          await _auth.signOut();

          if (!mounted) return;

          _showMessage(
            'Ton e-mail n’est pas encore vérifié. '
            'Un nouveau lien vient de t’être envoyé. '
            'Consulte ta boîte mail et tes courriers indésirables.',
          );
        } on FirebaseAuthException catch (e) {
          await _auth.signOut();

          if (!mounted) return;

          if (e.code == 'too-many-requests') {
            _showMessage(
              'Trop de demandes. Attends un peu avant de réessayer.',
            );
          } else if (e.code == 'network-request-failed') {
            _showMessage(
              'Vérifie ta connexion Internet et réessaie.',
            );
          } else {
            _showMessage(
              e.message ??
                  'Impossible d’envoyer le lien de vérification.',
            );
          }
        }

        return;
      }

      if (!mounted) return;

      _enter();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      switch (e.code) {
        case 'invalid-email':
          _showMessage('Adresse email invalide.');
          break;
        case 'user-not-found':
        case 'invalid-credential':
        case 'wrong-password':
          _showMessage('Email ou mot de passe incorrect.');
          break;
        case 'user-disabled':
          _showMessage('Ce compte a été désactivé.');
          break;
        case 'too-many-requests':
          _showMessage(
            'Trop de tentatives. Réessaie plus tard.',
          );
          break;
        case 'network-request-failed':
          _showMessage(
            'Erreur réseau. Vérifie ta connexion Internet.',
          );
          break;
        default:
          _showMessage(
            e.message ?? 'Erreur de connexion à Firebase.',
          );
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Une erreur est survenue. Réessaie.');
      }
    } finally {
      if (mounted) {
        setState(() => isLoggingIn = false);
      }
    }
  }

  // ========================================
  // CONNEXION GOOGLE
  // ========================================

  Future<void> _googleLogin() async {
    if (isLoggingIn) return;

    setState(() => isLoggingIn = true);

    try {
      // 1. Sélectionner le compte Google
      final googleUser =
          await GoogleSignIn.instance.authenticate();

      // 2. Récupérer le jeton Google
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        _showMessage(
          'Impossible de récupérer le jeton Google.',
        );
        return;
      }

      // 3. Authentifier avec Firebase
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final userCredential =
          await _auth.signInWithCredential(credential);

      final firebaseUser = userCredential.user;

      if (firebaseUser == null || firebaseUser.email == null) {
        await _auth.signOut();
        _showMessage(
          'Impossible de récupérer le compte Google.',
        );
        return;
      }

      // 4. Vérifier si l'utilisateur existe dans SQLite
      final localUser = await _userRepository.getUserByEmail(
        firebaseUser.email!,
      );

      if (localUser == null) {
        await _auth.signOut();

        if (!mounted) return;

        _showMessage(
          'Aucun compte StudyMate trouvé. '
          'Inscris-toi d’abord.',
        );
        return;
      }

      // 5. L'utilisateur existe dans SQLite
      if (!mounted) return;

      _enter();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      switch (e.code) {
        case 'account-exists-with-different-credential':
          _showMessage(
            'Cette adresse utilise déjà une autre méthode de connexion.',
          );
          break;
        case 'network-request-failed':
          _showMessage('Vérifie ta connexion Internet.');
          break;
        case 'user-disabled':
          _showMessage('Ce compte a été désactivé.');
          break;
        case 'too-many-requests':
          _showMessage(
            'Trop de tentatives. Réessaie plus tard.',
          );
          break;
        default:
          _showMessage(
            e.message ?? 'Erreur de connexion Google.',
          );
      }
    } on GoogleSignInException catch (e) {
      if (!mounted) return;

      if (e.code == GoogleSignInExceptionCode.canceled) {
        return;
      }

      _showMessage(
        'Connexion Google impossible. '
        'Vérifie la configuration Android.',
      );
    } catch (e) {
      if (mounted) {
        _showMessage('Erreur : $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoggingIn = false);
      }
    }
  }

  // ========================================
  // NAVIGATION
  // ========================================

  void _enter() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const Shell(),
      ),
    );
  }

  void _openRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  // ========================================
  // INTERFACE
  // ========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  24, 24, 24, 30,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Connexion', style: SM.h(22)),
                    const SizedBox(height: 6),
                    Text(
                      'Connecte-toi pour continuer.',
                      style: SM.b(14, color: SM.muted),
                    ),
                    const SizedBox(height: 20),

                    // Email
                    TextField(
                      controller: emailController,
                      enabled: !isLoggingIn,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      onChanged: (_) {
                        if (emailError != null) {
                          setState(() => emailError = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Email',
                        errorText: emailError,
                        prefixIcon: const Icon(
                          LucideIcons.mail,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Mot de passe
                    TextField(
                      controller: passwordController,
                      enabled: !isLoggingIn,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      onChanged: (_) {
                        if (passwordError != null) {
                          setState(() => passwordError = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Mot de passe',
                        errorText: passwordError,
                        errorMaxLines: 2,
                        prefixIcon: const Icon(
                          LucideIcons.lock,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                          icon: Icon(
                            obscurePassword
                                ? LucideIcons.eye
                                : LucideIcons.eyeOff,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Mot de passe oublié
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isLoggingIn
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                        child: Text(
                          'Mot de passe oublié ?',
                          style: SM.b(
                            13,
                            color: SM.primary,
                            w: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Connexion email
                    ElevatedButton.icon(
                      onPressed: isLoggingIn ? null : _login,
                      icon: isLoggingIn
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(LucideIcons.logIn),
                      label: Text(
                        isLoggingIn
                            ? 'Connexion en cours...'
                            : 'Se connecter',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Séparateur
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          child: Text(
                            'ou',
                            style: SM.b(
                              13,
                              color: SM.muted,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Connexion Google
                    OutlinedButton.icon(
                      onPressed:
                          isLoggingIn ? null : _googleLogin,
                      icon: const Icon(
                        Icons.g_mobiledata,
                        size: 28,
                      ),
                      label: Text(
                        isLoggingIn
                            ? 'Connexion en cours...'
                            : 'Continuer avec Google',
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Inscription
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Pas encore de compte ?',
                          style: SM.b(
                            14,
                            color: SM.muted,
                          ),
                        ),
                        TextButton(
                          onPressed:
                              isLoggingIn ? null : _openRegister,
                          child: Text(
                            "S'inscrire",
                            style: SM.b(
                              14,
                              color: SM.primary,
                              w: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================
  // HEADER ANIMÉ
  // ========================================

  Widget _buildHeader() {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SM.primary, SM.ai],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(40),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(40),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value * 2 * math.pi;
            final pulse = 1 + 0.06 * math.sin(t * 2);

            return Stack(
              children: [
                Positioned(
                  top: -40 + math.sin(t) * 8,
                  right: -30 + math.cos(t) * 8,
                  child: _circle(160),
                ),
                Positioned(
                  bottom: 20 + math.cos(t) * 8,
                  left: -40 + math.sin(t) * 8,
                  child: _circle(120),
                ),
                _floating(
                  t: t,
                  icon: LucideIcons.bookOpen,
                  alignment: const Alignment(-0.82, -0.5),
                  phase: 0,
                  delayMs: 0,
                ),
                _floating(
                  t: t,
                  icon: LucideIcons.lightbulb,
                  alignment: const Alignment(0.82, -0.55),
                  phase: 1.5,
                  delayMs: 150,
                ),
                _floating(
                  t: t,
                  icon: LucideIcons.pencil,
                  alignment: const Alignment(-0.78, 0.6),
                  phase: 3,
                  delayMs: 300,
                ),
                _floating(
                  t: t,
                  icon: LucideIcons.sparkles,
                  alignment: const Alignment(0.8, 0.55),
                  phase: 4.5,
                  delayMs: 450,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: pulse,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: 0.15,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.graduationCap,
                            color: SM.primary,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration:
                            const Duration(milliseconds: 700),
                        curve: Curves.easeOut,
                        builder: (_, v, child) => Opacity(
                          opacity: v,
                          child: Transform.translate(
                            offset: Offset(0, (1 - v) * 16),
                            child: child,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'StudyMate',
                              style: SM.h(28).copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Révise mieux, ensemble.',
                              style: SM.b(
                                15,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _floating({
    required double t,
    required IconData icon,
    required Alignment alignment,
    required double phase,
    required int delayMs,
    double size = 22,
  }) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(0, math.sin(t + phase) * 7),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(
            milliseconds: 600 + delayMs,
          ),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: v,
              child: child,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(
                SM.rBadge + 4,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: size,
            ),
          ),
        ),
      ),
    );
  }

  Widget _circle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.12),
      ),
    );
  }
}
