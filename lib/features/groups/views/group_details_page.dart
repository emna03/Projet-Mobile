import 'package:flutter/material.dart';
import '../../../core/auth/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/group.dart';
import '../models/join_request.dart';
import '../viewmodels/group_viewmodel.dart';
import 'edit_group_page.dart';
import '../../group_chat/viewmodels/group_chat_viewmodel.dart';
import '../../group_chat/views/group_chat_page.dart';

/// Detailed view of a group: info, members, pending requests (owner only).
class GroupDetailsPage extends StatefulWidget {
  final Group group;
  final GroupViewModel viewModel;

  const GroupDetailsPage({
    super.key,
    required this.group,
    required this.viewModel,
  });

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final group =
            widget.viewModel.getGroupById(widget.group.id) ?? widget.group;
        final status = widget.viewModel.membershipStatus(group);
        final isOwner = status == MembershipStatus.owner;
        final pendingRequests = widget.viewModel.pendingRequestsFor(group.id);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Détails du groupe'),
            actions: [
              if (isOwner) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Modifier',
                  onPressed: () => _navigateToEdit(context, group),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.danger),
                  tooltip: 'Supprimer',
                  onPressed: () => _confirmDelete(context, group),
                ),
              ],
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Header card ───────────────────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.groups_rounded,
                                color: AppColors.primary, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    AppBadge(
                                      group.isPublic ? 'Public' : 'Privé',
                                      type: group.isPublic
                                          ? AppBadgeType.success
                                          : AppBadgeType.warning,
                                    ),
                                    AppBadge(group.level,
                                        type: AppBadgeType.primary),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Description',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        group.description,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.muted, height: 1.5),
                      ),
                      if (group.owner != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.person_outline,
                                size: 16, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Text(
                              'Créateur : ${group.owner!.name}',
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Capacity bar ──────────────────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Membres du groupe',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text),
                          ),
                          Text(
                            '${group.memberCount} / ${group.maxMembers}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: group.maxMembers > 0
                              ? group.memberCount / group.maxMembers
                              : 0,
                          backgroundColor: AppColors.primarySoft,
                          color: group.isFull
                              ? AppColors.danger
                              : AppColors.primary,
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Member list ───────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Liste des membres (${group.memberCount})',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOwner && !group.isFull)
                      ElevatedButton.icon(
                        onPressed: () =>
                            _showAddMemberModal(context, group),
                        icon: const Icon(Icons.person_add_alt_1_outlined,
                            size: 16),
                        label: const Text('Ajouter'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 36),
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (group.members.isEmpty)
                  const AppEmptyState(
                    title: 'Aucun membre',
                    message: "Ce groupe n'a pas encore de membres inscrits.",
                  )
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: group.members.length,
                      separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: AppColors.primarySoft,
                          indent: 16,
                          endIndent: 16),
                      itemBuilder: (_, i) {
                        final member = group.members[i];
                        final isCurrentUser =
                            member.id == AppSession.currentUserId;
                        final isMemberOwner = member.id == group.ownerId;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: member.avatarColor,
                            child: Text(member.initials,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  member.name,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text),
                                ),
                              ),
                              if (isMemberOwner)
                                const AppBadge('Créateur',
                                    type: AppBadgeType.primary),
                              if (!isMemberOwner && isCurrentUser)
                                const AppBadge('Vous',
                                    type: AppBadgeType.success),
                            ],
                          ),
                          subtitle: Text(
                            '${member.role} · ${member.email}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: isOwner && !isMemberOwner
                              ? IconButton(
                                  icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: AppColors.danger,
                                      size: 20),
                                  tooltip: 'Retirer du groupe',
                                  onPressed: () => _removeMember(
                                      context, group, member.id),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),

                // ── Pending requests (owner only) ─────────────────────────
                if (isOwner && pendingRequests.isNotEmpty) ...[
                  const Text(
                    'Demandes en attente',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text),
                  ),
                  const SizedBox(height: 8),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pendingRequests.length,
                      separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: AppColors.primarySoft,
                          indent: 16,
                          endIndent: 16),
                      itemBuilder: (_, i) => _RequestTile(
                        request: pendingRequests[i],
                        onAccept: () =>
                            _handleAccept(context, pendingRequests[i]),
                        onReject: () =>
                            _handleReject(context, pendingRequests[i]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Chat button (members and owner only) ──────────────────
                if (status == MembershipStatus.owner ||
                    status == MembershipStatus.member) ...[  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _openChat(context, group),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Ouvrir la discussion'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // ── Bottom action (join / leave / request) ─────────────────
                _buildBottomAction(context, group, status),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Bottom action button ─────────────────────────────────────────────────

  Widget _buildBottomAction(
      BuildContext context, Group group, MembershipStatus status) {
    switch (status) {
      case MembershipStatus.owner:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _navigateToEdit(context, group),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Modifier'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger),
                onPressed: () => _confirmDelete(context, group),
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('Supprimer'),
              ),
            ),
          ],
        );
      case MembershipStatus.member:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger)),
            onPressed: () => _handleLeave(context, group),
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Quitter le groupe'),
          ),
        );
      case MembershipStatus.requested:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: BorderSide(color: AppColors.accent)),
            onPressed: () => _handleCancelRequest(context, group),
            icon: const Icon(Icons.hourglass_empty, size: 16),
            label: const Text('Demande envoyée — Annuler'),
          ),
        );
      case MembershipStatus.full:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.muted),
            onPressed: null,
            icon: const Icon(Icons.lock_outline, size: 16),
            label: const Text('Groupe complet'),
          ),
        );
      case MembershipStatus.none:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: group.isPublic
                ? () => _handleJoin(context, group)
                : () => _handleRequest(context, group),
            icon: Icon(
              group.isPublic
                  ? Icons.add_circle_outline
                  : Icons.send_outlined,
              size: 16,
            ),
            label: Text(group.isPublic
                ? 'Rejoindre le groupe'
                : 'Demander à rejoindre'),
          ),
        );
    }
  }

  // ─── Membership handlers ──────────────────────────────────────────────────

  Future<void> _handleJoin(BuildContext context, Group group) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await widget.viewModel.joinGroup(group.id);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      backgroundColor:
          error == null ? AppColors.success : AppColors.danger,
      content: Text(
          error ?? 'Vous avez rejoint « ${group.name} » !'),
    ));
  }

  Future<void> _handleLeave(BuildContext context, Group group) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.rCard)),
        title: const Text('Quitter le groupe ?'),
        content:
            Text("Êtes-vous sûr de vouloir quitter « ${group.name} » ?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size(100, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await widget.viewModel.leaveGroup(group.id);
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(
      backgroundColor:
          error == null ? AppColors.text : AppColors.danger,
      content: Text(
          error ?? 'Vous avez quitté « ${group.name} ».'),
    ));
  }

  Future<void> _handleRequest(BuildContext context, Group group) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await widget.viewModel.sendJoinRequest(group.id);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      backgroundColor:
          error == null ? AppColors.primary : AppColors.danger,
      content: Text(error ?? 'Demande envoyée avec succès.'),
    ));
  }

  Future<void> _handleCancelRequest(
      BuildContext context, Group group) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await widget.viewModel.cancelJoinRequest(group.id);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      backgroundColor:
          success ? AppColors.text : AppColors.danger,
      content: Text(
          success ? 'Demande annulée.' : "Erreur lors de l'annulation."),
    ));
  }

  Future<void> _handleAccept(
      BuildContext context, JoinRequest request) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await widget.viewModel.acceptRequest(request);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      backgroundColor:
          error == null ? AppColors.success : AppColors.danger,
      content: Text(error ??
          '${request.userName ?? "L'utilisateur"} a été ajouté(e) au groupe.'),
    ));
  }

  Future<void> _handleReject(
      BuildContext context, JoinRequest request) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await widget.viewModel.rejectRequest(request);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      backgroundColor:
          success ? AppColors.text : AppColors.danger,
      content: Text(success ? 'Demande refusée.' : "Erreur lors du refus."),
    ));
  }

  Future<void> _removeMember(
      BuildContext context, Group group, String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await widget.viewModel.removeMember(group.id, userId);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      backgroundColor:
          error == null ? AppColors.text : AppColors.danger,
      content: Text(error ?? 'Membre retiré du groupe.'),
    ));
  }

  // ─── Navigation / modals ──────────────────────────────────────────────────

  void _openChat(BuildContext context, Group group) {
    final chatVm = GroupChatViewModel(
      groupId: group.id,
      groupName: group.name,
      groupOwnerId: group.ownerId,
      memberCount: group.memberCount,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupChatPage(viewModel: chatVm),
      ),
    );
  }

  void _navigateToEdit(BuildContext context, Group group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditGroupPage(group: group, viewModel: widget.viewModel),
      ),
    );
  }

  void _showAddMemberModal(BuildContext context, Group group) {
    final nonMembers = widget.viewModel.allUsers
        .where((u) => !group.members.any((m) => m.id == u.id))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ajouter un membre',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              if (nonMembers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Tous les utilisateurs disponibles sont déjà dans ce groupe.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: nonMembers.length,
                    itemBuilder: (_, i) {
                      final user = nonMembers[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: user.avatarColor,
                          child: Text(user.initials,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(user.name),
                        subtitle: Text(user.role),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size(80, 36)),
                          onPressed: () async {
                            final messenger =
                                ScaffoldMessenger.of(context);
                            Navigator.pop(ctx);
                            final error = await widget.viewModel
                                .addMemberDirectly(group.id, user.id);
                            if (!context.mounted) return;
                            messenger.showSnackBar(SnackBar(
                              backgroundColor: error == null
                                  ? AppColors.success
                                  : AppColors.danger,
                              content: Text(error ??
                                  '${user.name} a été ajouté(e) au groupe.'),
                            ));
                          },
                          child: const Text('Ajouter'),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Group group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.rCard)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Expanded(
                child: Text('Supprimer le groupe ?',
                    overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: Text(
            "Êtes-vous sûr de vouloir supprimer le groupe « ${group.name} » ?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size(100, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final success = await widget.viewModel.deleteGroup(group.id);
      if (!context.mounted) return;
      if (success) {
        messenger.showSnackBar(SnackBar(
            backgroundColor: AppColors.text,
            content: Text(
                'Le groupe « ${group.name} » a été supprimé.')));
        navigator.pop();
      }
    }
  }
}

// ─── Request tile widget ──────────────────────────────────────────────────

class _RequestTile extends StatelessWidget {
  final JoinRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestTile({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(Icons.person_outline, color: AppColors.primary),
      ),
      title: Text(request.userName ?? request.userId,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text)),
      subtitle: Text(
        'Demande envoyée le ${_formatDate(request.createdAt)}',
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 24),
            tooltip: 'Accepter',
            onPressed: onAccept,
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined,
                color: AppColors.danger, size: 24),
            tooltip: 'Refuser',
            onPressed: onReject,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
