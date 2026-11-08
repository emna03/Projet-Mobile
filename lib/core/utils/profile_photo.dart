import 'package:flutter/foundation.dart';

/// Chemin de la photo de profil (null = pas de photo -> initiales).
/// Partagé entre ProfileScreen et EditProfileScreen.
final ValueNotifier<String?> profilePhotoPath = ValueNotifier<String?>(null);