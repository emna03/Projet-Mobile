import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/profile_photo.dart';
import '../../../core/theme/app_theme.dart';
import '../models/user.dart';
import '../repositories/user_repository.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final UserRepository _userRepository = UserRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  AppUser? _currentUser;

  final TextEditingController nomController = TextEditingController();
  final TextEditingController prenomController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController filiereController =
      TextEditingController(text: 'Génie logiciel');

  String? _photoPath;
  String? nomError;
  String? prenomError;
  String? phoneError;
  String? filiereError;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    nomController.addListener(_refresh);
    prenomController.addListener(_refresh);

    _loadProfile();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    nomController.dispose();
    prenomController.dispose();
    phoneController.dispose();
    emailController.dispose();
    filiereController.dispose();
    super.dispose();
  }

  // ========================================
  // CHARGER LE PROFIL DEPUIS SQLITE
  // ========================================
  Future<void> _loadProfile() async {
    try {
      final email = _auth.currentUser?.email;

      if (email == null || email.trim().isEmpty) {
        throw Exception('Aucun utilisateur connecté.');
      }

      final user = await _userRepository.getUserByEmail(email);

      if (user == null) {
        throw Exception('Profil introuvable dans SQLite.');
      }

      if (!mounted) return;

      setState(() {
        _currentUser = user;

        nomController.text = user.nom;
        prenomController.text = user.prenom;
        phoneController.text = user.telephone;
        emailController.text = user.email;

        _photoPath = user.photoPath ?? profilePhotoPath.value;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de chargement du profil : $e'),
        ),
      );
    }
  }

  // ========================================
  // INITIALLES DE L'AVATAR
  // ========================================
  String get _initials {
    final prenom = prenomController.text.trim();
    final nom = nomController.text.trim();

    final first = prenom.isNotEmpty ? prenom[0] : '';
    final second = nom.isNotEmpty ? nom[0] : '';

    final result = (first + second).toUpperCase();

    return result.isEmpty ? '?' : result;
  }

  // ========================================
  // VALIDATION
  // ========================================
  bool _validate() {
    final nom = nomController.text.trim();
    final prenom = prenomController.text.trim();
    final phone = phoneController.text.trim();
    final filiere = filiereController.text.trim();

    String? nErr;
    String? pErr;
    String? phErr;
    String? fErr;

    if (nom.length < 2) {
      nErr = 'Le nom doit contenir au moins 2 caractères.';
    }

    if (prenom.length < 2) {
      pErr = 'Le prénom doit contenir au moins 2 caractères.';
    }

    if (phone.isNotEmpty &&
        !RegExp(r'^\+?\d{8,15}$').hasMatch(phone)) {
      phErr = 'Numéro invalide (8 à 15 chiffres).';
    }

    if (filiere.isEmpty) {
      fErr = 'Veuillez saisir votre filière.';
    }

    setState(() {
      nomError = nErr;
      prenomError = pErr;
      phoneError = phErr;
      filiereError = fErr;
    });

    return nErr == null &&
        pErr == null &&
        phErr == null &&
        fErr == null;
  }

  // ========================================
  // ENREGISTRER DANS SQLITE
  // ========================================
  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (_isSaving) return;

    if (!_validate()) return;

    final currentUser = _currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le profil n’a pas encore été chargé.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updatedUser = AppUser(
        id: currentUser.id,
        nom: nomController.text.trim(),
        prenom: prenomController.text.trim(),
        telephone: phoneController.text.trim(),
        email: currentUser.email,
        role: currentUser.role,
        photoPath: _photoPath,
        statut: currentUser.statut,
      );

      final result = await _userRepository.updateUser(updatedUser);

      if (!mounted) return;

      if (result == 0) {
        throw Exception('Aucune modification enregistrée.');
      }

      setState(() {
        _currentUser = updatedUser;
      });

      // Met à jour la photo utilisée par l'application.
      profilePhotoPath.value = _photoPath;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil mis à jour avec succès.'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sauvegarde : $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ========================================
  // PHOTO : CAMÉRA / GALERIE
  // ========================================
  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 80,
      );

      if (file != null && mounted) {
        setState(() => _photoPath = file.path);
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’accéder à la photo.'),
        ),
      );
    }
  }

  void _pickPhoto() {
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        Widget option(
          IconData icon,
          String label,
          Color color,
          VoidCallback action,
        ) {
          return ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Text(
              label,
              style: SM.b(
                15,
                color: color == SM.danger ? SM.danger : SM.text,
                w: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              action();
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SM.primarySoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                option(
                  LucideIcons.camera,
                  'Prendre une photo',
                  SM.primary,
                  () => _pick(ImageSource.camera),
                ),
                option(
                  LucideIcons.image,
                  'Choisir dans la galerie',
                  SM.ai,
                  () => _pick(ImageSource.gallery),
                ),
                if (_photoPath != null)
                  option(
                    LucideIcons.trash2,
                    'Supprimer la photo',
                    SM.danger,
                    () => setState(() => _photoPath = null),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ========================================
  // CHAMP : LABEL
  // ========================================
  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: SM.b(14, w: FontWeight.w600),
      ),
    );
  }

  // ========================================
  // INTERFACE
  // ========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Modifier mon profil',
          style: SM.h(20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // AVATAR
                    Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.6, end: 1),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.elasticOut,
                        builder: (_, scale, child) =>
                            Transform.scale(
                          scale: scale,
                          child: child,
                        ),
                        child: GestureDetector(
                          onTap: _pickPhoto,
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [SM.primary, SM.ai],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 48,
                                  backgroundColor: SM.primary,
                                  backgroundImage: _photoPath != null
                                      ? FileImage(File(_photoPath!))
                                      : null,
                                  child: _photoPath == null
                                      ? Text(
                                          _initials,
                                          style: SM.h(28).copyWith(
                                            color: Colors.white,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: SM.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    LucideIcons.camera,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Center(
                      child: TextButton(
                        onPressed: _pickPhoto,
                        child: Text(
                          'Changer la photo',
                          style: SM.b(
                            14,
                            color: SM.primary,
                            w: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // INFORMATIONS PERSONNELLES
                    Text(
                      'Informations personnelles',
                      style: SM.h(17),
                    ),

                    const SizedBox(height: 14),

                    _label('Nom'),
                    TextField(
                      controller: nomController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) =>
                          setState(() => nomError = null),
                      decoration: InputDecoration(
                        hintText: 'Nom',
                        errorText: nomError,
                        prefixIcon: const Icon(LucideIcons.user),
                      ),
                    ),

                    const SizedBox(height: 14),

                    _label('Prénom'),
                    TextField(
                      controller: prenomController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) =>
                          setState(() => prenomError = null),
                      decoration: InputDecoration(
                        hintText: 'Prénom',
                        errorText: prenomError,
                        prefixIcon:
                            const Icon(LucideIcons.userRound),
                      ),
                    ),

                    const SizedBox(height: 14),

                    _label('Téléphone'),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) =>
                          setState(() => phoneError = null),
                      decoration: InputDecoration(
                        hintText: 'Téléphone (optionnel)',
                        errorText: phoneError,
                        prefixIcon: const Icon(LucideIcons.phone),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // EMAIL NON MODIFIABLE
                    _label('Email'),
                    TextField(
                      controller: emailController,
                      readOnly: true,
                      enableInteractiveSelection: false,
                      style: SM.b(15, color: SM.muted),
                      decoration: InputDecoration(
                        hintText: 'Email du compte',
                        helperText:
                            'L’email ne peut pas être modifié.',
                        fillColor:
                            SM.primarySoft.withOpacity(0.5),
                        prefixIcon: const Icon(LucideIcons.mail),
                        suffixIcon:
                            const Icon(LucideIcons.lock, size: 18),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ÉTUDES
                    Text('Études', style: SM.h(17)),

                    const SizedBox(height: 14),

                    _label('Filière'),
                    TextField(
                      controller: filiereController,
                      textCapitalization:
                          TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      onChanged: (_) =>
                          setState(() => filiereError = null),
                      decoration: InputDecoration(
                        hintText: 'Ex : Génie logiciel',
                        errorText: filiereError,
                        prefixIcon:
                            const Icon(LucideIcons.bookOpen),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ENREGISTRER
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(LucideIcons.check),
                      label: Text(
                        _isSaving
                            ? 'Enregistrement...'
                            : 'Enregistrer',
                      ),
                    ),

                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x),
                      label: const Text('Annuler'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
