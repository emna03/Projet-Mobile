import 'group.dart';

/// Visibility criterion for the groups list.
enum VisibilityFilter {
  all('Tous'),
  publicOnly('Publics'),
  privateOnly('Privés');

  const VisibilityFilter(this.label);
  final String label;
}

/// Capacity criterion for the groups list.
enum CapacityFilter {
  all('Tous'),
  available('Places disponibles'),
  full('Groupes complets');

  const CapacityFilter(this.label);
  final String label;
}

/// Immutable set of advanced filters applied to the groups list.
///
/// A `null` [level] means "Tous les niveaux".
class GroupFilters {
  final VisibilityFilter visibility;
  final CapacityFilter capacity;
  final String? level;

  const GroupFilters({
    this.visibility = VisibilityFilter.all,
    this.capacity = CapacityFilter.all,
    this.level,
  });

  static const GroupFilters none = GroupFilters();

  /// Number of non-default criteria (used for the filter icon badge).
  int get activeCount =>
      (visibility != VisibilityFilter.all ? 1 : 0) +
      (capacity != CapacityFilter.all ? 1 : 0) +
      (level != null ? 1 : 0);

  bool get hasActiveFilters => activeCount > 0;

  /// Returns `true` when [group] satisfies every active criterion.
  bool matches(Group group) {
    final matchesVisibility = switch (visibility) {
      VisibilityFilter.all => true,
      VisibilityFilter.publicOnly => group.isPublic,
      VisibilityFilter.privateOnly => !group.isPublic,
    };

    final matchesCapacity = switch (capacity) {
      CapacityFilter.all => true,
      CapacityFilter.available => group.memberCount < group.maxMembers,
      CapacityFilter.full => group.memberCount >= group.maxMembers,
    };

    final matchesLevel = level == null || group.level == level;

    return matchesVisibility && matchesCapacity && matchesLevel;
  }

  GroupFilters copyWith({
    VisibilityFilter? visibility,
    CapacityFilter? capacity,
    String? level,
    bool clearLevel = false,
  }) {
    return GroupFilters(
      visibility: visibility ?? this.visibility,
      capacity: capacity ?? this.capacity,
      level: clearLevel ? null : (level ?? this.level),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GroupFilters &&
      other.visibility == visibility &&
      other.capacity == capacity &&
      other.level == level;

  @override
  int get hashCode => Object.hash(visibility, capacity, level);
}
