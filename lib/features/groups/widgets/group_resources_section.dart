import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/resource_scope.dart';
import '../../../core/widgets/sm_widgets.dart';
import '../../resources/models/resource.dart';

/// Ressources pédagogiques « réservées au groupe », affichées dans le détail
/// d'un groupe.
///
/// Réutilise le module Ressources (même ViewModel, mêmes pages de détail et
/// de formulaire, même règle d'accès `canView`). Les non-membres ne voient
/// jamais la liste, que le groupe soit public ou privé.
class GroupResourcesSection extends StatelessWidget {
  final String groupId;
  final String groupName;
  final bool isMember;

  const GroupResourcesSection({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.isMember,
  });

  @override
  Widget build(BuildContext context) {
    final vm = ResourceScope.of(context);
    if (!vm.loadedOnce && !vm.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => vm.load());
    }

    final resources = isMember ? vm.resourcesForGroup(groupId) : const <Resource>[];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ressources du groupe',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text),
                ),
              ),
              if (isMember && vm.canCreate)
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.resourceForm,
                    arguments: groupId,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Partager'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isMember)
            const Text(
              'Les ressources de ce groupe sont réservées à ses membres.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            )
          else if (vm.loading && !vm.loadedOnce)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (resources.isEmpty)
            Text(
              vm.canCreate
                  ? 'Aucune ressource partagée. Touchez « Partager » pour en ajouter une.'
                  : 'Aucune ressource partagée avec ce groupe pour le moment.',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            )
          else
            for (final r in resources)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  r.attachedKind == ResourceFileKind.powerpoint
                      ? Icons.slideshow
                      : r.hasFile
                          ? Icons.picture_as_pdf
                          : Icons.description_outlined,
                  color: AppColors.primary,
                ),
                title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${r.subject} · ${r.author}'),
                trailing: SMBadge(
                  r.isFree ? 'Gratuit' : 'Payant',
                  kind: r.isFree ? BadgeKind.free : BadgeKind.paid,
                ),
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.resourceDetail,
                  arguments: r.id,
                ),
              ),
        ],
      ),
    );
  }
}
