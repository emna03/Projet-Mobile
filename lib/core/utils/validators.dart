/// Centralized input validation rules for forms across the StudyMate application.
class FormValidators {
  FormValidators._();

  /// Validates a group name.
  ///
  /// Rules:
  /// - Mandatory (non-empty after trim)
  /// - Length: between 3 and 50 characters
  /// - Must contain at least one alphanumeric character
  static String? validateGroupName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez saisir le nom du groupe.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return 'Le nom doit contenir au moins 3 caractères.';
    }
    if (trimmed.length > 50) {
      return 'Le nom ne peut pas dépasser 50 caractères.';
    }
    final hasLetterOrDigit = RegExp(r'[a-zA-Z0-9À-ÿ]').hasMatch(trimmed);
    if (!hasLetterOrDigit) {
      return 'Le nom doit contenir des lettres ou des chiffres.';
    }
    return null;
  }

  /// Validates a group description.
  ///
  /// Rules:
  /// - Mandatory (non-empty after trim)
  /// - Length: between 10 and 300 characters
  static String? validateGroupDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez saisir une description.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 10) {
      return 'La description doit contenir au moins 10 caractères.';
    }
    if (trimmed.length > 300) {
      return 'La description ne peut pas dépasser 300 caractères.';
    }
    return null;
  }

  /// Validates the academic level selection.
  static String? validateLevel(String? value, List<String> allowedLevels) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez sélectionner un niveau d\'études.';
    }
    if (!allowedLevels.contains(value)) {
      return 'Niveau d\'études non valide.';
    }
    return null;
  }

  /// Validates the group capacity relative to selected members.
  static String? validateCapacity({
    required int maxMembers,
    required int selectedCount,
  }) {
    if (maxMembers < 2) {
      return 'La capacité minimale est de 2 membres.';
    }
    if (maxMembers > 50) {
      return 'La capacité maximale ne peut pas dépasser 50 membres.';
    }
    if (selectedCount > maxMembers) {
      return 'La capacité ($maxMembers) ne peut pas être inférieure au nombre de membres ($selectedCount).';
    }
    return null;
  }
}
