import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../data/mock.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});
  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  String visibilityFilter = 'Tout';
  String priceFilter = 'Tout';
  String subjectFilter = 'Tout';
  String searchQuery = '';
  late final listItems = <Resource>[...resources];

  Future<void> _openForm({Resource? existing}) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final author = TextEditingController(text: existing?.author ?? '');
    final pages = TextEditingController(text: '${existing?.pages ?? 10}');
    var subject = existing?.subject ?? 'Spring Boot';
    var visibility = existing?.visibility ?? 'Public';
    var free = existing?.free ?? true;

    final result = await showModalBottomSheet<Resource>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SM.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(existing == null ? 'Créer une ressource' : 'Modifier la ressource', style: SM.h(20)),
              const SizedBox(height: 16),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Titre')),
              const SizedBox(height: 12),
              TextField(controller: author, decoration: const InputDecoration(labelText: 'Auteur')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: subject,
                decoration: const InputDecoration(labelText: 'Matière'),
                items: ['Spring Boot', 'Docker', 'Microservices', 'REST']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => set(() => subject = v!),
              ),
              const SizedBox(height: 12),
              Text('Visibilité', style: SM.b(14, w: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final v in ['Public', 'Privé', 'Groupe'])
                  SMChip(v, selected: visibility == v, onTap: () => set(() => visibility = v)),
              ]),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Gratuit', style: SM.b(15, w: FontWeight.w600)),
                activeThumbColor: SM.success,
                value: free,
                onChanged: (v) => set(() => free = v),
              ),
              TextField(
                controller: pages,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Pages'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (title.text.trim().length < 3) return;
                    final n = int.tryParse(pages.text) ?? 10;
                    Navigator.pop(
                      ctx,
                      existing == null
                          ? Resource('r${DateTime.now().millisecondsSinceEpoch}', title.text.trim(), subject,
                              author.text.trim().isEmpty ? 'Moi' : author.text.trim(), free, visibility, n)
                          : existing.copyWith(
                              title: title.text.trim(),
                              subject: subject,
                              author: author.text.trim().isEmpty ? existing.author : author.text.trim(),
                              free: free,
                              visibility: visibility,
                              pages: n,
                            ),
                    );
                  },
                  child: Text(existing == null ? 'Créer' : 'Enregistrer'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (existing == null) {
        listItems.insert(0, result);
      } else {
        final i = listItems.indexWhere((r) => r.id == existing.id);
        if (i >= 0) listItems[i] = result;
      }
    });
  }

  Future<void> _delete(Resource r) async {
    if (!await confirmDelete(context, r.title) || !mounted) return;
    setState(() => listItems.removeWhere((e) => e.id == r.id));
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ['Tout', ...listItems.map((r) => r.subject).toSet()];
    final visibilities = ['Tout', 'Public', 'Privé', 'Groupe'];
    final prices = ['Tout', 'Gratuit', 'Payant'];

    final list = listItems.where((r) {
      final matchVisibility = visibilityFilter == 'Tout' || r.visibility == visibilityFilter;
      final matchPrice = priceFilter == 'Tout' || (priceFilter == 'Gratuit' ? r.free : !r.free);
      final matchSubject = subjectFilter == 'Tout' || r.subject == subjectFilter;
      final matchSearch = r.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          r.subject.toLowerCase().contains(searchQuery.toLowerCase());
      return matchVisibility && matchPrice && matchSubject && matchSearch;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        const PageTitle('Ressources', subtitle: 'Gestion des ressources pédagogiques'),
        CrudButtons(onCreate: () => _openForm()),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: SM.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SM.border),
          ),
          child: TextField(
            onChanged: (val) => setState(() => searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Rechercher une ressource...',
              hintStyle: SM.b(15, color: SM.muted),
              prefixIcon: const Icon(LucideIcons.search, color: SM.muted, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Matière', style: SM.b(14, w: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final s in subjects)
              Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SMChip(s, selected: subjectFilter == s, onTap: () => setState(() => subjectFilter = s))),
          ]),
        ),
        const SizedBox(height: 12),
        Text('Visibilité', style: SM.b(14, w: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final v in visibilities)
              Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SMChip(v, selected: visibilityFilter == v, onTap: () => setState(() => visibilityFilter = v))),
          ]),
        ),
        const SizedBox(height: 12),
        Text('Prix', style: SM.b(14, w: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final p in prices)
              Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SMChip(p, selected: priceFilter == p, onTap: () => setState(() => priceFilter = p))),
          ]),
        ),
        const SizedBox(height: 24),
        Text('${list.length} résultat(s)', style: SM.b(14, color: SM.muted)),
        const SizedBox(height: 12),
        for (final r in list) ...[
          SMCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, style: SM.b(16, w: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${r.subject} · ${r.author}', style: SM.b(13, color: SM.muted)),
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: [
                SMBadge(r.free ? 'Gratuit' : 'Payant', kind: r.free ? BadgeKind.free : BadgeKind.paid),
                SMBadge(r.visibility == 'Public' ? '🔓 Public' : r.visibility == 'Privé' ? '🔒 Privé' : '👥 Groupe'),
              ]),
              const SizedBox(height: 12),
              CrudButtons(
                onView: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ResourceDetailScreen(r))),
                onEdit: () => _openForm(existing: r),
                onDelete: () => _delete(r),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class ResourceDetailScreen extends StatefulWidget {
  final Resource r;
  const ResourceDetailScreen(this.r, {super.key});
  @override
  State<ResourceDetailScreen> createState() => _ResourceDetailScreenState();
}

class _ResourceDetailScreenState extends State<ResourceDetailScreen> {
  String? panel;

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    return Scaffold(
      appBar: AppBar(backgroundColor: SM.bg, title: Text(r.subject, style: SM.h(17))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(r.title, style: SM.h(24)),
        const SizedBox(height: 6),
        Text('Par ${r.author} · ${r.pages} pages', style: SM.b(14, color: SM.muted)),
        const SizedBox(height: 12),
        Wrap(spacing: 6, children: [
          SMBadge(r.free ? 'Gratuit' : 'Payant', kind: r.free ? BadgeKind.free : BadgeKind.paid),
          SMBadge(r.visibility == 'Public' ? '🔓 Public' : r.visibility == 'Privé' ? '🔒 Privé' : '👥 Groupe'),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _aiButton('Résumé', LucideIcons.sparkles)),
          const SizedBox(width: 12),
          Expanded(child: _aiButton('Flashcards', LucideIcons.layers)),
        ]),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: SM.anim,
          child: panel == null
              ? const SizedBox.shrink()
              : SMCard(
                  key: ValueKey(panel),
                  color: SM.aiSoft,
                  child: Text(
                    panel == 'Résumé'
                        ? 'Cette ressource présente les notions clés de ${r.subject} : concepts, configuration et bonnes pratiques, avec des exemples concrets.'
                        : 'Flashcard 1/10\nQuestion : à quoi sert ${r.subject} ?\nTouchez pour voir la réponse.',
                    style: SM.b(15),
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _aiButton(String label, IconData icon) => ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: SM.aiSoft, foregroundColor: SM.ai),
        onPressed: () => setState(() => panel = label),
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
}
