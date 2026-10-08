import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../data/mock.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});
  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  String mode = 'Toutes';
  final booked = <String>{};
  late final items = <Session>[...sessions];

  Future<void> _openForm({Session? existing}) async {
    final subject = TextEditingController(text: existing?.subject ?? '');
    final date = TextEditingController(text: existing?.date ?? 'Ven. 10 oct.');
    final time = TextEditingController(text: existing?.time ?? '18:00');
    final price = TextEditingController(text: '${existing?.price ?? 0}');
    var sessionMode = existing?.mode ?? 'En ligne';

    final result = await showModalBottomSheet<Session>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SM.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(existing == null ? 'Créer une séance' : 'Modifier la séance', style: SM.h(20)),
              const SizedBox(height: 16),
              TextField(controller: subject, decoration: const InputDecoration(labelText: 'Matière')),
              const SizedBox(height: 12),
              TextField(controller: date, decoration: const InputDecoration(labelText: 'Date')),
              const SizedBox(height: 12),
              TextField(controller: time, decoration: const InputDecoration(labelText: 'Heure')),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                for (final m in ['En ligne', 'Présentiel'])
                  SMChip(m, selected: sessionMode == m, onTap: () => set(() => sessionMode = m)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Prix (DT)'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (subject.text.trim().length < 2) return;
                    final p = int.tryParse(price.text) ?? 0;
                    Navigator.pop(
                      ctx,
                      existing == null
                          ? Session('s${DateTime.now().millisecondsSinceEpoch}', subject.text.trim(), date.text.trim(),
                              time.text.trim(), sessionMode, p, 10, 10, false)
                          : existing.copyWith(
                              subject: subject.text.trim(),
                              date: date.text.trim(),
                              time: time.text.trim(),
                              mode: sessionMode,
                              price: p,
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
        items.insert(0, result);
      } else {
        final i = items.indexWhere((s) => s.id == existing.id);
        if (i >= 0) items[i] = result;
      }
    });
  }

  Future<void> _delete(Session s) async {
    if (!await confirmDelete(context, s.subject) || !mounted) return;
    setState(() => items.removeWhere((e) => e.id == s.id));
  }

  void _view(Session s) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SM.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SM.rCard)),
        title: Text(s.subject, style: SM.h(18)),
        content: Text('${s.date} · ${s.time}\n${s.mode}\n${s.price == 0 ? 'Gratuit' : '${s.price} DT'}\n${s.seatsLeft}/${s.seats} places',
            style: SM.b(14, color: SM.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Fermer', style: SM.b(14, color: SM.primary, w: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = items.where((s) => mode == 'Toutes' || s.mode == mode);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        const PageTitle('Séances', subtitle: 'Révisions en ligne ou en présentiel'),
        CrudButtons(onCreate: () => _openForm()),
        const SizedBox(height: 16),
        Row(children: [
          for (final m in ['Toutes', 'En ligne', 'Présentiel'])
            Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SMChip(m, selected: mode == m, onTap: () => setState(() => mode = m))),
        ]),
        const SizedBox(height: 16),
        for (final s in list) ...[
          SMCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(s.subject, style: SM.b(16, w: FontWeight.w600))),
                SMBadge(s.price == 0 ? 'Gratuit' : '${s.price} DT', kind: s.price == 0 ? BadgeKind.free : BadgeKind.paid),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(LucideIcons.calendar, size: 16, color: SM.muted),
                const SizedBox(width: 6),
                Text('${s.date} · ${s.time}', style: SM.b(13, color: SM.muted)),
                const SizedBox(width: 12),
                Icon(s.mode == 'En ligne' ? LucideIcons.video : LucideIcons.mapPin, size: 16, color: SM.muted),
                const SizedBox(width: 6),
                Text(s.mode, style: SM.b(13, color: SM.muted)),
              ]),
              const SizedBox(height: 6),
              Text('${s.seatsLeft} places restantes sur ${s.seats}', style: SM.b(13, color: SM.muted)),
              const SizedBox(height: 12),
              CrudButtons(
                onView: () => _view(s),
                onEdit: () => _openForm(existing: s),
                onDelete: () => _delete(s),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => setState(() => booked.add(s.id)),
                child: Text(s.booked ? 'Rejoindre' : booked.contains(s.id) ? 'Réservée' : 'Réserver'),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
