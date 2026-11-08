/// Single source of truth for the academic levels supported by StudyMate.
///
/// These values are persisted as-is in the `groups.level` column, so they
/// must stay consistent across creation, edition and filtering screens.
class AcademicLevels {
  AcademicLevels._();

  static const List<String> all = ['Licence 2', 'Licence 3', 'Master 1'];
}
