import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// User model representing a member or student in the system.
class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final int avatarColorIndex;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'Étudiant',
    this.avatarColorIndex = 0,
  });

  /// Helper to generate initials from full name (e.g., "Sarah Ben Ali" -> "SB")
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  /// Color associated with user's avatar
  Color get avatarColor {
    return AppColors.avatarColors[avatarColorIndex % AppColors.avatarColors.length];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
