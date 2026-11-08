import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/groups/viewmodels/group_viewmodel.dart';

import '../../mocks/fake_group_repository.dart';

/// Notifications de demandes d'adhésion à un groupe privé :
/// le propriétaire est notifié et accepte (le membre rejoint) ou refuse
/// (la demande est rejetée) ; le demandeur est notifié de la réponse.
void main() {
  late FakeGroupRepository repo;
  late GroupViewModel owner; // u0 possède le groupe privé g2
  late GroupViewModel requester; // u2 demande à rejoindre g2
  late List<GroupNotice> ownerNotices;
  late List<GroupNotice> requesterNotices;

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    repo = FakeGroupRepository();
    owner = GroupViewModel(repository: repo, currentUserIdProvider: () => 'u0');
    requester = GroupViewModel(repository: repo, currentUserIdProvider: () => 'u2');
    ownerNotices = [];
    requesterNotices = [];
    owner.notices.listen(ownerNotices.add);
    requester.notices.listen(requesterNotices.add);
    await owner.loadData();
    await requester.loadData();
  });

  test('le propriétaire reçoit une notification pour une nouvelle demande', () async {
    expect(await requester.sendJoinRequest('g2'), isNull);
    await owner.loadData(silent: true); // déclenché par le temps réel en production
    await flush();

    expect(owner.pendingRequestCount, 1);
    expect(ownerNotices, hasLength(1));
    expect(ownerNotices.single.request?.userId, 'u2');
    expect(ownerNotices.single.message, contains('veut rejoindre'));
  });

  test('accepter : le demandeur rejoint le groupe et en est notifié', () async {
    await requester.sendJoinRequest('g2');
    await owner.loadData(silent: true);
    final request = owner.allPendingRequests.single;

    expect(await owner.acceptRequest(request), isNull);
    expect(owner.pendingRequestCount, 0);
    expect(owner.getGroupById('g2')!.members.any((m) => m.id == 'u2'), isTrue);

    await requester.loadData(silent: true);
    await flush();
    expect(requester.memberGroupIds, contains('g2'));
    expect(requesterNotices.single.message, contains('acceptée'));
  });

  test('refuser : la demande est rejetée et le demandeur en est notifié', () async {
    await requester.sendJoinRequest('g2');
    await owner.loadData(silent: true);
    final request = owner.allPendingRequests.single;

    expect(await owner.rejectRequest(request), isTrue);
    expect(owner.pendingRequestCount, 0);
    expect(owner.getGroupById('g2')!.members.any((m) => m.id == 'u2'), isFalse);

    await requester.loadData(silent: true);
    await flush();
    expect(requester.memberGroupIds, isNot(contains('g2')));
    expect(requesterNotices.single.message, contains('refusée'));
  });

  test('pas de notification pour une demande que l\'on annule soi-même', () async {
    await requester.sendJoinRequest('g2');
    expect(await requester.cancelJoinRequest('g2'), isTrue);
    await requester.loadData(silent: true);
    await flush();
    expect(requesterNotices, isEmpty);
  });

  test('un non-propriétaire ne peut ni accepter ni refuser', () async {
    await requester.sendJoinRequest('g2');
    await owner.loadData(silent: true);
    final request = owner.allPendingRequests.single;
    expect(await requester.acceptRequest(request), isNotNull);
    expect(await requester.rejectRequest(request), isFalse);
  });
}
