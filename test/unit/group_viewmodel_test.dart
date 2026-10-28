import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/core/auth/app_session.dart';
import 'package:studymate/features/groups/models/group.dart';
import 'package:studymate/features/groups/models/group_filters.dart';
import 'package:studymate/features/groups/viewmodels/group_viewmodel.dart';
import 'package:studymate/features/users/models/user.dart';
import '../mocks/fake_group_repository.dart';

Future<void> _waitDebounce() => Future.delayed(
    GroupViewModel.searchDebounceDuration + const Duration(milliseconds: 50));

void main() {
  group('GroupViewModel Unit Tests', () {
    late FakeGroupRepository fakeRepo;
    late GroupViewModel viewModel;

    setUp(() {
      fakeRepo = FakeGroupRepository();
      viewModel = GroupViewModel(repository: fakeRepo);
    });

    test('Loads initial data successfully', () async {
      await viewModel.loadData();

      expect(viewModel.groups.length, 2);
      expect(viewModel.allUsers.length, 4);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('Filters groups by search query (name or description)', () async {
      await viewModel.loadData();

      viewModel.setSearchQuery('Docker');
      await _waitDebounce();
      expect(viewModel.filteredGroups.length, 1);
      expect(viewModel.filteredGroups.first.name, 'Docker & DevOps');

      viewModel.setSearchQuery('Boot');
      await _waitDebounce();
      expect(viewModel.filteredGroups.length, 1);
      expect(viewModel.filteredGroups.first.name, 'Spring Boot Masters');

      // Description match, case-insensitive
      viewModel.setSearchQuery('CONTENEURS');
      await _waitDebounce();
      expect(viewModel.filteredGroups.single.name, 'Docker & DevOps');

      viewModel.clearSearch();
      expect(viewModel.filteredGroups.length, 2);
    });

    test('Search is debounced: list only updates after the delay', () async {
      await viewModel.loadData();

      viewModel.setSearchQuery('Docker');
      expect(viewModel.searchInput, 'Docker');
      expect(viewModel.filteredGroups.length, 2); // not applied yet

      await _waitDebounce();
      expect(viewModel.searchQuery, 'Docker');
      expect(viewModel.filteredGroups.length, 1);
    });

    test('Filters by visibility', () async {
      await viewModel.loadData();

      viewModel.applyFilters(
          const GroupFilters(visibility: VisibilityFilter.publicOnly));
      expect(viewModel.filteredGroups.single.id, 'g1');

      viewModel.applyFilters(
          const GroupFilters(visibility: VisibilityFilter.privateOnly));
      expect(viewModel.filteredGroups.single.id, 'g2');

      viewModel.clearVisibilityFilter();
      expect(viewModel.filteredGroups.length, 2);
    });

    test('Filters by capacity using real member counts', () async {
      final users = await FakeGroupRepository().getAllUsers();
      final repo = FakeGroupRepository(initialGroups: [
        Group(
          id: 'full',
          name: 'Java Full',
          description: 'Groupe Java complet',
          level: 'Licence 2',
          maxMembers: 2,
          ownerId: 'u1',
          // Owner is part of the membership rows → counted once.
          members: [users[1], users[2]],
          createdAt: DateTime.now(),
        ),
        Group(
          id: 'open',
          name: 'Java Open',
          description: 'Groupe Java avec places',
          level: 'Licence 2',
          maxMembers: 3,
          ownerId: 'u1',
          members: [users[1], users[2]],
          createdAt: DateTime.now(),
        ),
      ]);
      final vm = GroupViewModel(repository: repo);
      await vm.loadData();

      vm.applyFilters(const GroupFilters(capacity: CapacityFilter.full));
      expect(vm.filteredGroups.single.id, 'full');

      vm.applyFilters(const GroupFilters(capacity: CapacityFilter.available));
      expect(vm.filteredGroups.single.id, 'open');
    });

    test('Search text and all filters combine', () async {
      await viewModel.loadData();

      viewModel.setSearchQuery('spring');
      await _waitDebounce();
      viewModel.applyFilters(const GroupFilters(
        visibility: VisibilityFilter.publicOnly,
        capacity: CapacityFilter.available,
        level: 'Licence 3',
      ));
      expect(viewModel.filteredGroups.single.id, 'g1');
      expect(viewModel.filters.activeCount, 3);

      viewModel.clearLevelFilter();
      viewModel.applyFilters(viewModel.filters.copyWith(level: 'Master 1'));
      expect(viewModel.filteredGroups, isEmpty);
      expect(viewModel.hasActiveCriteria, isTrue);

      viewModel.resetAllCriteria();
      expect(viewModel.filteredGroups.length, 2);
      expect(viewModel.hasActiveCriteria, isFalse);
    });

    test('Filters groups by academic level', () async {
      await viewModel.loadData();

      viewModel.setSelectedLevel('Licence 3');
      expect(viewModel.filteredGroups.length, 1);
      expect(viewModel.filteredGroups.first.level, 'Licence 3');

      viewModel.setSelectedLevel('Master 1');
      expect(viewModel.filteredGroups.length, 1);
      expect(viewModel.filteredGroups.first.level, 'Master 1');

      viewModel.setSelectedLevel('Tous');
      expect(viewModel.filteredGroups.length, 2);
    });

    test('Correctly calculates membership status', () async {
      await viewModel.loadData();

      final g1 = viewModel.getGroupById('g1')!; // Owned by u1, current is u0 (not member)
      final g2 = viewModel.getGroupById('g2')!; // Owned by u0 (current user)

      expect(viewModel.membershipStatus(g2), MembershipStatus.owner);
      expect(viewModel.membershipStatus(g1), MembershipStatus.none);
    });

    test('Current user can join a public group and become a member', () async {
      await viewModel.loadData();

      final g1 = viewModel.getGroupById('g1')!;
      expect(viewModel.membershipStatus(g1), MembershipStatus.none);

      final error = await viewModel.joinGroup(g1.id);
      expect(error, isNull);

      final updatedG1 = viewModel.getGroupById('g1')!;
      expect(viewModel.membershipStatus(updatedG1), MembershipStatus.member);
      expect(updatedG1.members.any((m) => m.id == AppSession.currentUserId), isTrue);
    });

    test('Current user cannot leave a group they own', () async {
      await viewModel.loadData();

      final g2 = viewModel.getGroupById('g2')!;
      final error = await viewModel.leaveGroup(g2.id);

      expect(error, contains('créateur ne peut pas quitter'));
    });

    test('Creates and deletes a group', () async {
      await viewModel.loadData();
      final initialCount = viewModel.groups.length;

      final success = await viewModel.createGroup(
        name: 'Algorithmique Avancée',
        description: 'Arbres, graphes et programmation dynamique',
        level: 'Licence 2',
        selectedMembers: const <User>[],
      );

      expect(success, isTrue);
      expect(viewModel.groups.length, initialCount + 1);

      final created = viewModel.groups.first;
      expect(created.name, 'Algorithmique Avancée');
      expect(created.ownerId, AppSession.currentUserId);

      final deleted = await viewModel.deleteGroup(created.id);
      expect(deleted, isTrue);
      expect(viewModel.groups.length, initialCount);
    });

    test('Sends join request to a private group', () async {
      final privateGroup = Group(
        id: 'g_priv',
        name: 'Private Study Club',
        description: 'Invites only',
        level: 'Master 1',
        isPublic: false,
        maxMembers: 5,
        ownerId: 'u1',
        members: const [],
        createdAt: DateTime.now(),
      );

      fakeRepo = FakeGroupRepository(initialGroups: [privateGroup]);
      viewModel = GroupViewModel(repository: fakeRepo);
      await viewModel.loadData();

      expect(viewModel.membershipStatus(privateGroup), MembershipStatus.none);

      final err = await viewModel.sendJoinRequest('g_priv');
      expect(err, isNull);

      final reqs = await fakeRepo.getPendingRequests('g_priv');
      expect(reqs.length, 1);
      expect(reqs.first.userId, AppSession.currentUserId);
    });

    test('Pending join request status persists across app restarts / data reloads', () async {
      final privateGroup = Group(
        id: 'g_priv2',
        name: 'Private Security Lab',
        description: 'Cybersecurity research',
        level: 'Master 2',
        isPublic: false,
        maxMembers: 6,
        ownerId: 'u2', // Owned by someone else
        members: const [],
        createdAt: DateTime.now(),
      );

      fakeRepo = FakeGroupRepository(initialGroups: [privateGroup]);
      viewModel = GroupViewModel(repository: fakeRepo);
      await viewModel.loadData();

      expect(viewModel.membershipStatus(privateGroup), MembershipStatus.none);

      // Send join request
      final err = await viewModel.sendJoinRequest('g_priv2');
      expect(err, isNull);
      expect(viewModel.membershipStatus(privateGroup), MembershipStatus.requested);

      // Simulate app restart: create a brand new ViewModel instance
      final restartedViewModel = GroupViewModel(repository: fakeRepo);
      await restartedViewModel.loadData();

      // Verify that status is still requested after restart
      final reloadedGroup = restartedViewModel.getGroupById('g_priv2')!;
      expect(
        restartedViewModel.membershipStatus(reloadedGroup),
        MembershipStatus.requested,
      );
    });
  });
}
