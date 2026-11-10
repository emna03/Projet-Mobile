import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studymate/core/constants/session_user.dart';
import 'package:studymate/core/services/group_membership.dart';
import 'package:studymate/features/gestion_user/repositories/user_repository.dart';
import 'package:studymate/features/groups/viewmodels/group_viewmodel.dart';
import 'package:studymate/features/resources/models/resource.dart';
import 'package:studymate/features/resources/repositories/resource_repository.dart';
import 'package:studymate/features/resources/viewmodels/resource_viewmodel.dart';

import '../mocks/fake_group_repository.dart';

/// Appartenance simulée (en production : GroupViewModel / Firestore).
class FakeMembership extends ChangeNotifier implements GroupMembershipSource {
  FakeMembership(this.memberGroups);

  @override
  List<GroupRef> memberGroups;

  @override
  Set<String> get memberGroupIds => memberGroups.map((g) => g.id).toSet();

  void set(List<GroupRef> groups) {
    memberGroups = groups;
    notifyListeners();
  }
}

class InMemoryResources extends ResourceRepository {
  InMemoryResources(this.rows);
  final List<Resource> rows;
  int _next = 100;

  @override
  Future<List<Resource>> getAll() async => List.of(rows);

  @override
  Future<int> create(Resource resource) async {
    final id = _next++;
    rows.add(resource.copyWith(id: id));
    return id;
  }

  @override
  Future<int> update(Resource resource) async {
    final i = rows.indexWhere((r) => r.id == resource.id);
    if (i >= 0) rows[i] = resource;
    return 1;
  }
}

Resource _res(int id, ResourceVisibility v, {String? groupId, String owner = 'prof@x.tn', bool free = true}) =>
    Resource(
      id: id,
      title: 'Ressource $id',
      subject: 'Sujet',
      author: 'Prof',
      ownerName: owner,
      content: 'Contenu de test suffisamment long.',
      visibility: v,
      groupId: groupId,
      groupName: groupId == null ? null : 'Groupe $groupId',
      isFree: free,
      price: free ? 0 : 12,
      pages: 3,
      createdAt: id,
    );

void main() {
  group('Ressources ↔ Groupes : visibilité « réservée à un groupe »', () {
    late FakeMembership membership;
    late ResourceViewModel vm;

    setUp(() async {
      membership = FakeMembership([const GroupRef('gA', 'Groupe A')]);
      vm = ResourceViewModel(
        InMemoryResources([
          _res(1, ResourceVisibility.public),
          _res(2, ResourceVisibility.private),
          _res(3, ResourceVisibility.group, groupId: 'gA'),
          _res(4, ResourceVisibility.group, groupId: 'gB', free: false),
          _res(5, ResourceVisibility.group, groupId: 'g2'), // ancien groupe fictif
        ]),
        groups: membership,
      );
      await vm.load();
    });

    test('un membre voit les ressources de son groupe, pas celles des autres', () {
      final ids = vm.visibleResources.map((r) => r.id).toSet();
      expect(ids, {1, 3});
      expect(vm.resourcesForGroup('gA').map((r) => r.id), [3]);
      expect(vm.resourcesForGroup('gB'), isEmpty);
    });

    test('les ressources privées restent privées', () {
      expect(vm.canView(vm.byId(2)!), isFalse);
    });

    test('rejoindre un groupe donne accès à ses ressources (payantes incluses, statut conservé)', () {
      var notified = false;
      vm.addListener(() => notified = true);
      membership.set(const [GroupRef('gA', 'Groupe A'), GroupRef('gB', 'Groupe B')]);
      expect(notified, isTrue);
      final r4 = vm.byId(4)!;
      expect(vm.canView(r4), isTrue);
      expect(r4.isFree, isFalse, reason: 'l\'appartenance ne rend pas la ressource gratuite');
    });

    test('quitter un groupe retire l\'accès', () {
      membership.set(const []);
      expect(vm.canView(vm.byId(3)!), isFalse);
      expect(vm.selectableGroups, isEmpty);
    });

    test('un enseignant ne peut pas associer une ressource à un groupe dont il n\'est pas membre', () async {
      SessionUser.role = 'teacher';
      addTearDown(() => SessionUser.role = '');
      final r = _res(0, ResourceVisibility.group, groupId: 'gB', owner: '').copyWith();
      await expectLater(
        vm.save(Resource(
          title: r.title,
          subject: r.subject,
          author: r.author,
          ownerName: '',
          content: r.content,
          visibility: ResourceVisibility.group,
          groupId: 'gB',
          isFree: true,
          pages: 1,
          createdAt: 1,
        )),
        throwsA(isA<StateError>()),
      );
      // Groupe autorisé : accepté.
      await vm.save(Resource(
        title: 'Partagée avec A',
        subject: 'S',
        author: 'A',
        ownerName: '',
        content: 'Contenu de test suffisamment long.',
        visibility: ResourceVisibility.group,
        groupId: 'gA',
        groupName: 'Groupe A',
        isFree: true,
        pages: 1,
        createdAt: 99,
      ));
      expect(vm.resourcesForGroup('gA').any((r) => r.title == 'Partagée avec A'), isTrue);
    });

    test('seul le propriétaire peut modifier ou supprimer une ressource', () async {
      SessionUser.role = 'teacher';
      addTearDown(() => SessionUser.role = '');
      final foreign = vm.byId(1)!; // propriétaire : prof@x.tn ≠ session
      await expectLater(vm.save(foreign.copyWith(title: 'Piratée')), throwsA(isA<StateError>()));
      await expectLater(vm.remove(1), throwsA(isA<StateError>()));
    });
  });

  group('GroupViewModel : session Firebase et permissions', () {
    test('un non-propriétaire ne peut ni modifier ni supprimer un groupe', () async {
      final vm = GroupViewModel(repository: FakeGroupRepository(), currentUserIdProvider: () => 'u0');
      await vm.loadData();
      final g1 = vm.getGroupById('g1')!; // propriétaire : u1
      expect(await vm.deleteGroup(g1.id), isFalse);
      expect(await vm.updateGroup(g1.copyWith(name: 'Renommé par un tiers')), isFalse);
      expect(await vm.removeMember(g1.id, 'u2'), isNotNull);
      expect(vm.getGroupById('g1'), isNotNull);
    });

    test('memberGroupIds suit les adhésions (pont vers le module Ressources)', () async {
      final vm = GroupViewModel(repository: FakeGroupRepository(), currentUserIdProvider: () => 'u0');
      await vm.loadData();
      expect(vm.memberGroupIds, {'g2'});
      expect(await vm.joinGroup('g1'), isNull);
      expect(vm.memberGroupIds, {'g1', 'g2'});
    });

    test('sans utilisateur connecté : aucun groupe chargé, actions refusées', () async {
      final vm = GroupViewModel(repository: FakeGroupRepository(), currentUserIdProvider: () => '');
      await vm.loadData();
      expect(vm.groups, isEmpty);
      expect(await vm.joinGroup('g1'), isNotNull);
      expect(
        await vm.createGroup(name: 'Groupe test', description: 'Description de test', level: 'Licence 2', selectedMembers: const []),
        isFalse,
      );
    });

    test('changement de compte : l\'état est rechargé pour le nouvel utilisateur', () async {
      var uid = 'u0';
      final session = StreamController<Object?>.broadcast();
      final vm = GroupViewModel(
        repository: FakeGroupRepository(),
        currentUserIdProvider: () => uid,
        sessionChanges: session.stream,
      );
      await vm.loadData();
      expect(vm.memberGroupIds, {'g2'});

      uid = 'u2';
      session.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(vm.memberGroupIds, {'g1'});

      uid = '';
      session.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(vm.groups, isEmpty);
      await session.close();
      vm.dispose();
    });
  });

  group('SQLite : collision studymate.db avec l\'ancien module Groupes', () {
    test('l\'ancienne base est préservée et la table des profils est créée', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = Directory.systemTemp.createTempSync('studymate_legacy');
      await databaseFactoryFfi.setDatabasesPath(dir.path);

      // Base laissée par Projet-Mobile-version-1 (schéma v2, même fichier).
      final legacy = await databaseFactoryFfi.openDatabase(
        p.join(dir.path, 'studymate.db'),
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            await db.execute('CREATE TABLE users (id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL UNIQUE, role TEXT, avatar_color INTEGER)');
            await db.execute('CREATE TABLE groups (id TEXT PRIMARY KEY, name TEXT NOT NULL, owner_id TEXT NOT NULL REFERENCES users(id))');
            await db.insert('users', {'id': 'u1', 'name': 'Sarah', 'email': 's@x.tn', 'role': 'Étudiant', 'avatar_color': 1});
            await db.insert('groups', {'id': 'g1', 'name': 'Spring', 'owner_id': 'u1'});
          },
        ),
      );
      await legacy.close();

      final repo = UserRepository();
      expect(await repo.getUsers(), isEmpty);
      expect(await repo.getUserByEmail('s@x.tn'), isNull);

      final check = await databaseFactoryFfi.openDatabase(p.join(dir.path, 'studymate.db'));
      final legacyUsers = await check.query('legacy_group_users');
      final groups = await check.query('groups');
      expect(legacyUsers.single['name'], 'Sarah');
      expect(groups.single['name'], 'Spring');
      await check.close();
    });
  });
}
