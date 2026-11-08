import 'package:flutter/material.dart';
import '../../../core/constants/session_user.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sm_widgets.dart';
import '../../../core/widgets/resource_scope.dart';
import '../models/resource.dart';

class ResourcesPage extends StatefulWidget {
  const ResourcesPage({super.key});

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = ResourceScope.of(context);
      if (!vm.loading || !vm.loadedOnce) vm.load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vm = ResourceScope.of(context);
    if (vm.loading) return;
    if (vm.loadedOnce && vm.loadedFor == SessionUser.email) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!vm.loading) vm.load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ResourceScope.of(context);
    final list = vm.visibleResources;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          PageTitle('Ressources',
              subtitle: vm.canCreate ? 'Cours, fiches et exercices partagés' : 'Consultation et favoris'),
          if (vm.canCreate) ...[
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.resourceForm),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter une ressource'),
            ),
            const SizedBox(height: 12),
          ],
          SearchField(
            'Rechercher une ressource',
            key: ValueKey('search-${vm.resetToken}'),
            controller: _search,
            onChanged: vm.setQuery,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final f in [
                'Tout',
                'Gratuit',
                'Payant',
                'Public',
                'Privé',
                'Groupe',
                'Favoris',
                'Plus récent',
                'Plus ancien',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SMChip(
                    f,
                    selected: f == 'Plus récent' || f == 'Plus ancien' ? vm.sort == f : vm.filter == f,
                    onTap: () => vm.setFilter(f),
                  ),
                ),
            ]),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                _search.clear();
                vm.clearFilters();
              },
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
              icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
              label: const Text('Réinitialiser les filtres'),
            ),
          ),
          const SizedBox(height: 8),
          if (vm.loading)
            const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
          else if (vm.error != null)
            Text(vm.error!, style: SM.b(14, color: SM.danger))
          else if (list.isEmpty)
            Text('Aucune ressource pour ce filtre.', style: SM.b(14, color: SM.muted))
          else
            for (final r in list) ...[
              _ResourceCard(resource: r),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final Resource resource;
  const _ResourceCard({required this.resource});

  @override
  Widget build(BuildContext context) {
    return SMCard(
      onTap: () => Navigator.pushNamed(context, AppRoutes.resourceDetail, arguments: resource.id),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(resource.title, style: SM.b(16, w: FontWeight.w600))),
          IconButton(
            tooltip: resource.isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
            onPressed: () => ResourceScope.of(context).toggleFavorite(resource),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              resource.isFavorite ? Icons.favorite : Icons.favorite_border,
              size: 20,
              color: resource.isFavorite ? SM.danger : SM.muted,
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text('${resource.subject} · ${resource.author}', style: SM.b(13, color: SM.muted)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          SMBadge(resource.isFree ? 'Gratuit' : 'Payant', kind: resource.isFree ? BadgeKind.free : BadgeKind.paid),
          SMBadge(resource.visibilityLabel),
          if (resource.hasFile) SMBadge(resource.attachedLabel),
        ]),
      ]),
    );
  }
}
