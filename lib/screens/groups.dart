import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../data/mock.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final requested = <String>{};
  final list = <Group>[...groups];
  final created = <String>{};

  Future<void> _openForm({Group? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final desc = TextEditingController();
    var level = existing?.level ?? 'Licence 3';
    var publicGroup = existing?.public ?? true;
    final g = await showModalBottomSheet<Group>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SM.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(existing == null ? 'Créer un groupe' : 'Modifier le groupe', style: SM.h(20)),
          const SizedBox(height: 16),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom du groupe')),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final l in ['Licence 2', 'Licence 3', 'Master 1'])
              SMChip(l, selected: level == l, onTap: () => set(() => level = l)),
          ]),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Groupe public', style: SM.b(15, w: FontWeight.w600)),
            activeThumbColor: SM.primary,
            value: publicGroup,
            onChanged: (v) => set(() => publicGroup = v),
          ),
          TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Description (facultatif)')),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () {
              if (name.text.trim().length < 3) return;
              Navigator.pop(
                ctx,
                existing == null
                    ? Group('n${DateTime.now().millisecondsSinceEpoch}', name.text.trim(), level, 1, 10, publicGroup)
                    : existing.copyWith(name: name.text.trim(), level: level, public: publicGroup),
              );
            },
            child: Text(existing == null ? 'Créer le groupe' : 'Enregistrer'),
          )),
        ]),
      )),
    );
    if (g != null && mounted) {
      setState(() {
        if (existing == null) {
          list.insert(0, g);
          created.add(g.id);
        } else {
          final i = list.indexWhere((e) => e.id == existing.id);
          if (i >= 0) list[i] = g;
        }
      });
    }
  }

  Future<void> _delete(Group g) async {
    if (!await confirmDelete(context, g.name) || !mounted) return;
    setState(() {
      list.removeWhere((e) => e.id == g.id);
      created.remove(g.id);
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          const PageTitle('Groupes d\'étude', subtitle: 'Apprends avec d\'autres étudiants'),
          CrudButtons(onCreate: () => _openForm()),
          const SizedBox(height: 12),
          const SearchField('Rechercher un groupe'),
          const SizedBox(height: 16),
          for (final g in list) ...[
            SMCard(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(g))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(g.name, style: SM.b(16, w: FontWeight.w600))),
                  if (created.contains(g.id)) ...[const SMBadge('Nouveau'), const SizedBox(width: 6)],
                  SMBadge(g.public ? 'Public' : 'Privé'),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(LucideIcons.users, size: 16, color: SM.muted),
                  const SizedBox(width: 6),
                  Text('${g.level} · ${g.members}/${g.max} membres', style: SM.b(13, color: SM.muted)),
                ]),
                const SizedBox(height: 12),
                CrudButtons(
                  onView: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(g))),
                  onEdit: () => _openForm(existing: g),
                  onDelete: () => _delete(g),
                ),
                if (!created.contains(g.id)) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: requested.contains(g.id) ? null : () => setState(() => requested.add(g.id)),
                    child: Text(requested.contains(g.id) ? 'Demande envoyée' : 'Demander à rejoindre'),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
}

class GroupDetailScreen extends StatelessWidget {
  final Group g;
  const GroupDetailScreen(this.g, {super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: SM.bg,
            title: Text(g.name, style: SM.h(17)),
            bottom: TabBar(
              isScrollable: true,
              labelColor: SM.primary,
              unselectedLabelColor: SM.muted,
              indicatorColor: SM.primary,
              labelStyle: SM.b(14, w: FontWeight.w600),
              tabs: const [Tab(text: 'Ressources'), Tab(text: 'Quiz'), Tab(text: 'Membres'), Tab(text: 'Séances')],
            ),
          ),
          body: TabBarView(children: [
            _list(resources.map((r) => r.title)),
            _list(['Quiz Docker · 10 questions', 'Quiz REST · 8 questions']),
            _list(['Sarah Ben Ali', 'Yassine Trabelsi', 'Ines Haddad', 'Karim Mansour', 'Nacef Jouini', 'Lina Gharbi']),
            _list(sessions.map((s) => '${s.subject} · ${s.date} ${s.time}')),
          ]),
        ),
      );

  Widget _list(Iterable<String> items) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final i in items) ...[
            SMCard(child: Text(i, style: SM.b(15, w: FontWeight.w600))),
            const SizedBox(height: 10),
          ]
        ],
      );
}
