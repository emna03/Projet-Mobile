
class AppUser {
  final int? id;
  final String nom;
  final String prenom;
  final String telephone;
  final String email;
  final String role;

  // Photo de profil stockée localement.
  final String? photoPath;

  // Justificatif enseignant hébergé sur ImgBB.
  final String? documentUrl;

  final String statut;

  const AppUser({
    this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.email,
    required this.role,
    this.photoPath,
    this.documentUrl,
    this.statut = 'active',
  });

  bool get isTeacher => role == 'teacher';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'email': email,
      'role': role,
      'photoPath': photoPath,
      'documentUrl': documentUrl,
      'statut': statut,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as int?,
      nom: map['nom'] as String,
      prenom: map['prenom'] as String,
      telephone: map['telephone'] as String,
      email: map['email'] as String,
      role: map['role'] as String,
      photoPath: map['photoPath'] as String?,
      documentUrl: map['documentUrl'] as String?,
      statut: map['statut'] as String? ?? 'active',
    );
  }
}
