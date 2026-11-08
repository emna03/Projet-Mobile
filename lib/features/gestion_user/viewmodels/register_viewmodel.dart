
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user.dart' as models;
import '../repositories/user_repository.dart';
import '../../../core/services/imgbb_service.dart';

class RegisterViewModel {
  final UserRepository _userRepository;
  final FirebaseAuth _auth;
  final ImgBBService _imgBBService;

  RegisterViewModel(
    this._userRepository, {
    required ImgBBService imgBBService,
    FirebaseAuth? auth,
  })  : _imgBBService = imgBBService,
        _auth = auth ?? FirebaseAuth.instance;

  String? validate({
    required String nom,
    required String prenom,
    required String telephone,
    required String email,
    required String password,
    required String confirmPassword,
    required String role,
    String? documentPath,
    bool isTeacherDocumentAccepted = false,
  }) {
    if (nom.trim().isEmpty ||
        prenom.trim().isEmpty ||
        telephone.trim().isEmpty ||
        email.trim().isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      return 'Veuillez remplir les champs obligatoires.';
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailRegex.hasMatch(email.trim())) {
      return 'Veuillez saisir une adresse email valide.';
    }

    if (password.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères.';
    }

    if (password != confirmPassword) {
      return 'Les mots de passe ne correspondent pas.';
    }

    if (role != 'student' && role != 'teacher') {
      return 'Veuillez sélectionner un rôle valide.';
    }

    if (role == 'teacher') {
      if (documentPath == null || documentPath.trim().isEmpty) {
        return 'Veuillez ajouter un justificatif enseignant.';
      }

      if (!isTeacherDocumentAccepted) {
        return 'Votre justificatif doit être vérifié avant l’inscription.';
      }
    }

    return null;
  }

  Future<models.AppUser> register({
    required String nom,
    required String prenom,
    required String telephone,
    required String email,
    required String password,
    required String confirmPassword,
    required String role,
    String? documentPath,
    String? photoPath,
    bool isTeacherDocumentAccepted = false,
  }) async {
    // 1. Validation
    final error = validate(
      nom: nom,
      prenom: prenom,
      telephone: telephone,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      role: role,
      documentPath: documentPath,
      isTeacherDocumentAccepted: isTeacherDocumentAccepted,
    );

    if (error != null) {
      throw Exception(error);
    }

    // 2. Création du compte Firebase
    UserCredential credential;

    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('Cette adresse email est déjà utilisée.');

        case 'weak-password':
          throw Exception('Le mot de passe est trop faible.');

        case 'invalid-email':
          throw Exception('Adresse email invalide.');

        case 'network-request-failed':
          throw Exception(
            'Problème de connexion. Vérifiez votre réseau.',
          );

        default:
          throw Exception(
            e.message ?? 'Erreur lors de la création du compte.',
          );
      }
    }

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      throw Exception('Impossible de créer le compte utilisateur.');
    }

    try {
      // 3. Envoi du justificatif enseignant vers ImgBB
      String? documentUrl;

      if (role == 'teacher') {
        documentUrl = await _imgBBService.uploadImage(
          documentPath!,
        );
      }

      // 4. Création du profil local
      final user = models.AppUser(
        nom: nom.trim(),
        prenom: prenom.trim(),
        telephone: telephone.trim(),
        email: firebaseUser.email ?? email.trim().toLowerCase(),
        role: role,
        photoPath: photoPath,
        documentUrl: documentUrl,
        statut: 'active',
      );

      // 5. Enregistrement dans SQLite
      await _userRepository.insertUser(user);

      return user;
    } catch (e) {
      // 6. Annulation du compte Firebase si une étape échoue
      try {
        await firebaseUser.delete();
      } catch (_) {
        // La suppression peut échouer si Firebase
        // exige une authentification récente.
      }

      rethrow;
    }
  }
}
