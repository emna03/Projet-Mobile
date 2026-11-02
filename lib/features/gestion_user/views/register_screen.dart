
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../repositories/user_repository.dart';
import '../services/ocr_service.dart';
import '../viewmodels/register_viewmodel.dart';
import 'register_header_widget.dart';
import 'role_selection_widget.dart';
import 'teacher_verification_widget.dart';
import '../../../core/services/imgbb_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  late final RegisterViewModel _viewModel = RegisterViewModel(
    UserRepository(),
    imgBBService: ImgBBService(
      apiKey: 'ffaedce924de3cc77dde73e869ed3cd4',
    ),
  );

  final OcrService _ocrService = OcrService();

  String selectedRole = 'student';
  String? documentPath;
  String extractedText = '';

  bool isTeacherDocumentAccepted = false;
  bool isReadingDocument = false;
  bool isRegistering = false;

  // Visibilité des mots de passe
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  final nomController = TextEditingController();
  final prenomController = TextEditingController();
  final telephoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // ========================================
  // SÉLECTION DU DOCUMENT ENSEIGNANT
  // ========================================

  Future<void> _selectDocument() async {
    if (isReadingDocument || isRegistering) return;

    setState(() {
      isReadingDocument = true;
      isTeacherDocumentAccepted = false;
    });

    try {
      final result = await _ocrService.pickAndRead(context);

      if (!mounted || result == null) return;

      setState(() {
        documentPath = result.path;
        extractedText = result.extractedText;
        isTeacherDocumentAccepted =
            result.isLikelyTeacherDocument;
      });

      _showMessage(result.message);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        documentPath = null;
        extractedText = '';
        isTeacherDocumentAccepted = false;
      });

      _showMessage(
        'Impossible de lire le document. '
        'Essaie avec une image plus nette.',
      );
    } finally {
      if (mounted) {
        setState(() => isReadingDocument = false);
      }
    }
  }

  // ========================================
  // CHANGEMENT DU RÔLE
  // ========================================

  void _changeRole(String role) {
    if (isRegistering || isReadingDocument) return;

    setState(() {
      selectedRole = role;
      isTeacherDocumentAccepted = false;

      if (role == 'student') {
        documentPath = null;
        extractedText = '';
      }
    });
  }

  // ========================================
  // INSCRIPTION
  // ========================================

  Future<void> _register() async {
    if (isRegistering || isReadingDocument) return;

    if (selectedRole == 'teacher') {
      if (documentPath == null ||
          documentPath!.trim().isEmpty) {
        _showMessage(
          'Ajoute un justificatif enseignant avant de continuer.',
        );
        return;
      }

      if (!isTeacherDocumentAccepted) {
        _showMessage(
          'Le justificatif n’a pas passé le contrôle. '
          'Choisis un document lisible et compatible.',
        );
        return;
      }
    }

    final error = _viewModel.validate(
      nom: nomController.text,
      prenom: prenomController.text,
      telephone: telephoneController.text,
      email: emailController.text,
      password: passwordController.text,
      confirmPassword: confirmPasswordController.text,
      role: selectedRole,
      documentPath: documentPath,
      isTeacherDocumentAccepted: isTeacherDocumentAccepted,
    );

    if (error != null) {
      _showMessage(error);
      return;
    }

    setState(() => isRegistering = true);

    try {
      final user = await _viewModel.register(
        nom: nomController.text,
        prenom: prenomController.text,
        telephone: telephoneController.text,
        email: emailController.text,
        password: passwordController.text,
        confirmPassword: confirmPasswordController.text,
        role: selectedRole,
        documentPath: documentPath,
        isTeacherDocumentAccepted:
            isTeacherDocumentAccepted,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            user.isTeacher
                ? 'Compte enseignant créé avec succès.'
                : 'Compte étudiant créé avec succès.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Retour à la page de connexion après l'inscription.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;

      final message = e.toString();

      if (message.contains('UNIQUE constraint failed') ||
          message.contains('email-already-in-use')) {
        _showMessage('Cette adresse email est déjà utilisée.');
      } else if (message.startsWith('Exception: ')) {
        _showMessage(
          message.substring('Exception: '.length),
        );
      } else {
        _showMessage(
          'Erreur lors de la création du compte. Réessaie.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => isRegistering = false);
      }
    }
  }

  // ========================================
  // MESSAGE
  // ========================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ========================================
  // DISPOSE
  // ========================================

  @override
  void dispose() {
    nomController.dispose();
    prenomController.dispose();
    telephoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }

  // ========================================
  // INTERFACE
  // ========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Créer un compte', style: SM.h(20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RegisterHeaderWidget(),
                const SizedBox(height: 20),

                Text(
                  'Bienvenue sur StudyMate',
                  textAlign: TextAlign.center,
                  style: SM.h(22),
                ),
                const SizedBox(height: 6),

                Text(
                  'Crée ton compte pour commencer à réviser.',
                  textAlign: TextAlign.center,
                  style: SM.b(14, color: SM.muted),
                ),
                const SizedBox(height: 28),

                Text('Je suis', style: SM.h(17)),
                const SizedBox(height: 12),

                RoleSelectionWidget(
                  selectedRole: selectedRole,
                  onRoleChanged: _changeRole,
                ),

                const SizedBox(height: 24),

                Text(
                  'Informations personnelles',
                  style: SM.h(17),
                ),
                const SizedBox(height: 14),

                // NOM
                TextField(
                  controller: nomController,
                  enabled: !isRegistering,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Nom',
                    prefixIcon: Icon(LucideIcons.user),
                  ),
                ),
                const SizedBox(height: 12),

                // PRÉNOM
                TextField(
                  controller: prenomController,
                  enabled: !isRegistering,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Prénom',
                    prefixIcon: Icon(LucideIcons.userRound),
                  ),
                ),
                const SizedBox(height: 12),

                // TÉLÉPHONE
                TextField(
                  controller: telephoneController,
                  enabled: !isRegistering,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'Téléphone',
                    prefixIcon: Icon(LucideIcons.phone),
                  ),
                ),
                const SizedBox(height: 12),

                // EMAIL
                TextField(
                  controller: emailController,
                  enabled: !isRegistering,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'Email',
                    prefixIcon: Icon(LucideIcons.mail),
                  ),
                ),

                // JUSTIFICATIF ENSEIGNANT
                if (selectedRole == 'teacher') ...[
                  const SizedBox(height: 24),
                  TeacherVerificationWidget(
                    documentPath: documentPath,
                    extractedText: extractedText,
                    isReading: isReadingDocument,
                    onSelectDocument: _selectDocument,
                  ),
                ],

                const SizedBox(height: 24),

                Text('Sécurité', style: SM.h(17)),
                const SizedBox(height: 14),

                // MOT DE PASSE AVEC BOUTON ŒIL
                TextField(
                  controller: passwordController,
                  enabled: !isRegistering,
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: 'Mot de passe',
                    prefixIcon: const Icon(LucideIcons.lock),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          isPasswordVisible = !isPasswordVisible;
                        });
                      },
                      icon: Icon(
                        isPasswordVisible
                            ? LucideIcons.eyeOff
                            : LucideIcons.eye,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // CONFIRMATION AVEC BOUTON ŒIL
                TextField(
                  controller: confirmPasswordController,
                  enabled: !isRegistering,
                  obscureText: !isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    hintText: 'Confirmer le mot de passe',
                    prefixIcon: const Icon(
                      LucideIcons.lockKeyhole,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          isConfirmPasswordVisible =
                              !isConfirmPasswordVisible;
                        });
                      },
                      icon: Icon(
                        isConfirmPasswordVisible
                            ? LucideIcons.eyeOff
                            : LucideIcons.eye,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // BOUTON INSCRIPTION
                ElevatedButton.icon(
                  onPressed:
                      (isReadingDocument || isRegistering)
                          ? null
                          : _register,
                  icon: isRegistering
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(LucideIcons.userPlus),
                  label: Text(
                    isRegistering
                        ? 'Création du compte...'
                        : "S'inscrire",
                  ),
                ),

                const SizedBox(height: 12),

                // BIOMÉTRIE
                OutlinedButton.icon(
                  onPressed: isRegistering
                      ? null
                      : () {
                          _showMessage(
                            'La connexion biométrique sera '
                            'ajoutée plus tard.',
                          );
                        },
                  icon: const Icon(LucideIcons.scanFace),
                  label: const Text(
                    'Activer Face ID / Empreinte',
                  ),
                ),

                const SizedBox(height: 16),

                // RETOUR CONNEXION
                TextButton(
                  onPressed: isRegistering
                      ? null
                      : () => Navigator.pop(context),
                  child: Text(
                    'J’ai déjà un compte',
                    style: SM.b(
                      15,
                      color: SM.primary,
                      w: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
