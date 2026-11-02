
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();

  bool emailSent = false;
  bool isLoading = false;

  static const int _resendDelay = 30;
  int _secondsLeft = 0;
  Timer? _timer;

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendDelay);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _sendResetEmail() async {
    final email = emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      _showMessage('Veuillez saisir votre adresse email.');
      return;
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailRegex.hasMatch(email)) {
      _showMessage('Veuillez saisir une adresse email valide.');
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      setState(() => emailSent = true);
      _startTimer();

      _showMessage(
        'Si un compte correspond à cette adresse, '
        'un email de réinitialisation va être envoyé.',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'Adresse email invalide.';
          break;
        case 'too-many-requests':
          message = 'Trop de tentatives. Réessaie plus tard.';
          break;
        case 'network-request-failed':
          message = 'Vérifie ta connexion Internet.';
          break;
        default:
          message = 'Impossible d’envoyer l’email. Réessaie.';
      }

      _showMessage(message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Une erreur est survenue. Réessaie.');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  @override
  void dispose() {
    _timer?.cancel();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mot de passe oublié', style: SM.h(20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: SM.primarySoft,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    emailSent
                        ? LucideIcons.mailCheck
                        : LucideIcons.lockKeyhole,
                    color: SM.primary,
                    size: 38,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                emailSent
                    ? 'Vérifie ta boîte mail'
                    : 'Réinitialiser ton mot de passe',
                textAlign: TextAlign.center,
                style: SM.h(23),
              ),

              const SizedBox(height: 8),

              Text(
                emailSent
                    ? 'Si un compte correspond à cette adresse, '
                        'tu recevras un lien pour créer un nouveau '
                        'mot de passe. Vérifie aussi tes courriers indésirables.'
                    : 'Entre ton adresse email. Firebase t’enverra '
                        'un lien sécurisé pour choisir un nouveau mot de passe.',
                textAlign: TextAlign.center,
                style: SM.b(14, color: SM.muted),
              ),

              const SizedBox(height: 32),

              Text(
                'Adresse email',
                style: SM.b(14, w: FontWeight.w600),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: emailController,
                enabled: !isLoading && !emailSent,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'exemple@email.com',
                  prefixIcon: Icon(LucideIcons.mail),
                ),
              ),

              const SizedBox(height: 20),

              if (!emailSent)
                ElevatedButton.icon(
                  onPressed: isLoading ? null : _sendResetEmail,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(LucideIcons.send),
                  label: Text(
                    isLoading
                        ? 'Envoi en cours...'
                        : 'Envoyer le lien',
                  ),
                ),

              if (emailSent) ...[
                ElevatedButton.icon(
                  onPressed: _secondsLeft == 0 && !isLoading
                      ? _sendResetEmail
                      : null,
                  icon: const Icon(LucideIcons.refreshCw),
                  label: Text(
                    _secondsLeft == 0
                        ? 'Renvoyer le lien'
                        : 'Renvoyer dans ${_secondsLeft}s',
                  ),
                ),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: () {
                    _timer?.cancel();
                    setState(() {
                      emailSent = false;
                      _secondsLeft = 0;
                    });
                  },
                  icon: const Icon(LucideIcons.mail),
                  label: const Text('Utiliser un autre email'),
                ),
              ],

              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.arrowLeft),
                label: const Text('Retour à la connexion'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
