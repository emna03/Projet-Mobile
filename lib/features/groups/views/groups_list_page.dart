import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/group.dart';
import '../models/group_filters.dart';
import '../viewmodels/group_viewmodel.dart';
import '../widgets/group_filter_sheet.dart';
import 'create_group_page.dart';
import 'edit_group_page.dart';
import 'group_details_page.dart';

/// Groups list screen – debounced search, advanced filters, and group cards.
class GroupsListPage extends StatefulWidget {
  final GroupViewModel viewModel;

  const GroupsListPage({
    super.key,
    required this.viewModel,
  });

  @override
  State<GroupsListPage> createState() => _GroupsListPageState();
}

class _GroupsListPageState extends State<GroupsListPage> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        final groups = viewModel.filteredGroups;

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PageHeader(
                          'Gestion des Groupes',
                          subtitle: "Consultez, créez et gérez vos groupes d'étude",
                          trailing: ElevatedButton.icon(
                            onPressed: () => _navigateToCreate(context),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Créer'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              minimumSize: const Size(0, 40),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SearchInputField(
                                hint: 'Rechercher par nom ou description...',
                                value: viewModel.searchInput,
                                onChanged: viewModel.setSearchQuery,
                                onClear: viewModel.clearSearch,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _FilterButton(
                              activeCount: viewModel.filters.activeCount,
                              onPressed: () => _openFilters(context),
                            ),
                          ],
                        ),
                        if (viewModel.filters.hasActiveFilters) ...[
                          const SizedBox(height: 12),
                          _ActiveFilterChips(
                            filters: viewModel.filters,
                            onClearVisibility: viewModel.clearVisibilityFilter,
                            onClearCapacity: viewModel.clearCapacityFilter,
                            onClearLevel: viewModel.clearLevelFilter,
                            onClearAll: viewModel.resetFilters,
                          ),
                        ],
                        if (!viewModel.isLoading) ...[
                          const SizedBox(height: 12),
                          Text(
                            _resultLabel(groups.length),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                if (viewModel.isLoading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (groups.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: viewModel.hasActiveCriteria
                        ? AppEmptyState(
                            icon: Icons.filter_alt_off_outlined,
                            title: 'Aucun groupe trouvé',
                            message: viewModel.searchQuery.isNotEmpty
                                ? 'Aucun groupe ne correspond à votre recherche '
                                    '« ${viewModel.searchQuery} » et aux filtres '
                                    'sélectionnés.'
                                : 'Aucun groupe ne correspond aux filtres '
                                    'sélectionnés.',
                            actionLabel: 'Réinitialiser les filtres',
                            actionIcon: Icons.restart_alt,
                            onAction: viewModel.resetAllCriteria,
                          )
                        : AppEmptyState(
                            title: 'Aucun groupe trouvé',
                            message: 'Aucun groupe disponible pour le moment.',
                            actionLabel: 'Créer un groupe',
                            onAction: () => _navigateToCreate(context),
                          ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final group = groups[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _GroupCard(
                              group: group,
                              status: viewModel.membershipStatus(group),
                              onTap: () => _navigateToDetails(context, group),
                              onEdit: () => _navigateToEdit(context, group),
                              onDelete: () => _confirmDelete(context, group),
                              onJoin: () => _handleJoin(context, group),
                              onLeave: () => _handleLeave(context, group),
                              onRequest: () => _handleRequest(context, group),
                              onCancelRequest: () =>
                                  _handleCancelRequest(context, group),
                            ),
                          );
                        },
                        childCount: groups.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _navigateToCreate(context),
            icon: const Icon(Icons.group_add),
            label: const Text('Nouveau groupe'),
          ),
        );
      },
    );
  }

  // ─── Filters ─────────────────────────────────────────────────────────────

  Future<void> _openFilters(BuildContext context) async {
    final result = await showGroupFilterSheet(
      context,
      initial: widget.viewModel.filters,
    );
    if (result != null) widget.viewModel.applyFilters(result);
  }

  String _resultLabel(int count) => switch (count) {
        0 => 'Aucun groupe trouvé',
        1 => '1 groupe trouvé',
        _ => '$count groupes trouvés',
      };

  // ─── Navigation ──────────────────────────────────────────────────────────

  void _navigateToCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGroupPage(viewModel: widget.viewModel),
      ),
    );
  }

  void _navigateToDetails(BuildContext context, Group group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GroupDetailsPage(group: group, viewModel: widget.viewModel),
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

  // ─── Membership actions ───────────────────────────────────────────────────

  Future<void> _handleJoin(BuildContext context, Group group) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await widget.viewModel.joinGroup(group.id);
    if (!mounted) return;
    if (error != null) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(error),
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.success,
        content: Text('Vous avez rejoint « ${group.name} » !'),
      ));
    }
  }

  Future<void> _handleLeave(BuildContext context, Group group) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.rCard),
        ),
        title: const Text('Quitter le groupe ?'),
        content: Text(
            "Êtes-vous sûr de vouloir quitter « ${group.name} » ?"),
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
    if (error != null) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(error),
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.text,
        content: Text('Vous avez quitté « ${group.name} ».'),
      ));
    }
  }

  Future<void> _handleRequest(BuildContext context, Group group) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await widget.viewModel.sendJoinRequest(group.id);
    if (!mounted) return;
    if (error != null) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(error),
      ));
    } else {
      messenger.showSnackBar(const SnackBar(
        backgroundColor: AppColors.primary,
        content: Text('Demande envoyée avec succès.'),
      ));
    }
  }

  Future<void> _handleCancelRequest(BuildContext context, Group group) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await widget.viewModel.cancelJoinRequest(group.id);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      backgroundColor: success ? AppColors.text : AppColors.danger,
      content: Text(success
          ? 'Demande annulée.'
          : 'Erreur lors de l\'annulation.'),
    ));
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(BuildContext context, Group group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.rCard),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Supprimer le groupe ?',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer le groupe « ${group.name} » ? '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(100, 40),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final success = await widget.viewModel.deleteGroup(group.id);
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor:
              success ? AppColors.text : AppColors.danger,
          content: Text(
            success
                ? 'Le groupe « ${group.name} » a été supprimé.'
                : 'Erreur lors de la suppression.',
          ),
        ),
      );
    }
  }
}

// ─── Filter button ──────────────────────────────────────────────────────────

class _FilterButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onPressed;

  const _FilterButton({required this.activeCount, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final active = activeCount > 0;
    return Badge(
      isLabelVisible: active,
      label: Text('$activeCount'),
      backgroundColor: AppColors.accent,
      offset: const Offset(-4, 4),
      child: Material(
        color: active ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.rButton),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppDimensions.rButton),
          child: Tooltip(
            message: 'Filtrer les groupes',
            child: SizedBox(
              width: 54,
              height: 54,
              child: Icon(
                Icons.tune_rounded,
                color: active ? Colors.white : AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Active filter chips ────────────────────────────────────────────────────

class _ActiveFilterChips extends StatelessWidget {
  final GroupFilters filters;
  final VoidCallback onClearVisibility;
  final VoidCallback onClearCapacity;
  final VoidCallback onClearLevel;
  final VoidCallback onClearAll;

  const _ActiveFilterChips({
    required this.filters,
    required this.onClearVisibility,
    required this.onClearCapacity,
    required this.onClearLevel,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (filters.visibility != VisibilityFilter.all)
          _chip(
            filters.visibility.label,
            filters.visibility == VisibilityFilter.publicOnly
                ? Icons.public
                : Icons.lock_outline,
            onClearVisibility,
          ),
        if (filters.capacity != CapacityFilter.all)
          _chip(
            filters.capacity.label,
            filters.capacity == CapacityFilter.available
                ? Icons.event_seat_outlined
                : Icons.block_outlined,
            onClearCapacity,
          ),
        if (filters.level != null)
          _chip(filters.level!, Icons.school_outlined, onClearLevel),
        if (filters.activeCount > 1)
          TextButton(
            onPressed: onClearAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Tout effacer'),
          ),
      ],
    );
  }

  Widget _chip(String label, IconData icon, VoidCallback onDeleted) {
    return InputChip(
      avatar: Icon(icon, size: 16, color: AppColors.primary),
      label: Text(label),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      backgroundColor: AppColors.primarySoft,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.rBadge),
      ),
      deleteIcon: const Icon(Icons.close, size: 16),
      deleteIconColor: AppColors.primary,
      deleteButtonTooltipMessage: 'Retirer le filtre',
      onDeleted: onDeleted,
    );
  }
}

// ─── Group Card ─────────────────────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  final Group group;
  final MembershipStatus status;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onRequest;
  final VoidCallback onCancelRequest;

  const _GroupCard({
    required this.group,
    required this.status,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onJoin,
    required this.onLeave,
    required this.onRequest,
    required this.onCancelRequest,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: icon + name + menu ────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Spring Boot · ${group.level}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (status == MembershipStatus.owner) ...[
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, color: AppColors.muted),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined,
                            size: 18, color: AppColors.text),
                        SizedBox(width: 8),
                        Text('Modifier'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: AppColors.danger),
                        SizedBox(width: 8),
                        Text('Supprimer',
                            style: TextStyle(color: AppColors.danger)),
                      ]),
                    ),
                  ],
                ),
              ] else ...[
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // ── Badges ─────────────────────────────────────────────────────
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              AppBadge(
                group.isPublic ? 'Public' : 'Privé',
                type:
                    group.isPublic ? AppBadgeType.success : AppBadgeType.warning,
              ),
              AppBadge(group.level, type: AppBadgeType.primary),
            ],
          ),

          const SizedBox(height: 10),

          // ── Description ────────────────────────────────────────────────
          Text(
            group.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.primarySoft),
          const SizedBox(height: 10),

          // ── Avatars + member count ─────────────────────────────────────
          Row(
            children: [
              OverlappingAvatars(
                avatars: group.members
                    .map((m) => (initials: m.initials, color: m.avatarColor))
                    .toList(),
              ),
              const SizedBox(width: 10),
              Text(
                '${group.memberCount}/${group.maxMembers} membres',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Action button ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    switch (status) {
      case MembershipStatus.owner:
        return _softButton(
          label: 'Gérer le groupe',
          icon: Icons.settings_outlined,
          onPressed: onEdit,
          color: AppColors.primary,
        );
      case MembershipStatus.member:
        return _softButton(
          label: 'Quitter le groupe',
          icon: Icons.logout,
          onPressed: onLeave,
          color: AppColors.danger,
          textColor: AppColors.danger,
          bgColor: const Color(0xFFFEE2E2),
        );
      case MembershipStatus.requested:
        return _softButton(
          label: 'Demande envoyée',
          icon: Icons.hourglass_empty_rounded,
          onPressed: onCancelRequest,
          color: AppColors.accent,
          textColor: const Color(0xFF92400E),
          bgColor: const Color(0xFFFEF3C7),
        );
      case MembershipStatus.full:
        return _softButton(
          label: 'Groupe complet',
          icon: Icons.lock_outline,
          onPressed: null,
          color: AppColors.muted,
          bgColor: const Color(0xFFEEEDF5),
          textColor: AppColors.muted,
        );
      case MembershipStatus.none:
        if (group.isPublic) {
          return _softButton(
            label: 'Rejoindre le groupe',
            icon: Icons.add_circle_outline,
            onPressed: onJoin,
            color: AppColors.primary,
          );
        } else {
          return _softButton(
            label: 'Demander à rejoindre',
            icon: Icons.send_outlined,
            onPressed: onRequest,
            color: AppColors.primary,
          );
        }
    }
  }

  Widget _softButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    Color? bgColor,
    Color? textColor,
  }) {
    final bg = bgColor ?? AppColors.primarySoft;
    final fg = textColor ?? color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDimensions.rButton),
        child: AnimatedContainer(
          duration: AppDimensions.anim,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppDimensions.rButton),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
