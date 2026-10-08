import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SMCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;
  const SMCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color = SM.card, this.onTap});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: SM.anim,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(SM.rCard), boxShadow: SM.shadow),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(SM.rCard),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

enum BadgeKind { free, paid, neutral }

class SMBadge extends StatelessWidget {
  final String label;
  final BadgeKind kind;
  const SMBadge(this.label, {super.key, this.kind = BadgeKind.neutral});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      BadgeKind.free => (const Color(0xFFD1FAE5), const Color(0xFF065F46)),
      BadgeKind.paid => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      BadgeKind.neutral => (const Color(0xFFEEEDF5), SM.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(SM.rBadge)),
      child: Text(label, style: SM.b(12, color: fg, w: FontWeight.w600)),
    );
  }
}

class SMChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const SMChip(this.label, {super.key, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: SM.anim,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? SM.primary : Colors.white,
            borderRadius: BorderRadius.circular(SM.rButton),
            boxShadow: selected ? SM.shadow : null,
          ),
          child: Text(label, style: SM.b(14, color: selected ? Colors.white : SM.text, w: FontWeight.w600)),
        ),
      );
}

class PageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const PageTitle(this.title, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: SM.h(24)),
        if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: SM.b(14, color: SM.muted))],
        const SizedBox(height: 20),
      ]);
}

class SearchField extends StatelessWidget {
  final String hint;
  const SearchField(this.hint, {super.key});
  @override
  Widget build(BuildContext context) => TextField(
        decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.search, color: SM.muted)),
      );
}

Future<bool> confirmDelete(BuildContext context, String label) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: SM.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SM.rCard)),
      title: Text('Supprimer', style: SM.h(18)),
      content: Text('Supprimer « $label » ? Cette action est locale.', style: SM.b(14, color: SM.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: SM.b(14, color: SM.muted, w: FontWeight.w600))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Supprimer', style: SM.b(14, color: SM.danger, w: FontWeight.w600))),
      ],
    ),
  );
  return ok == true;
}

/// Boutons CRUD (créer / voir / modifier / supprimer) alignés sur la charte StudyMate.
class CrudButtons extends StatelessWidget {
  final VoidCallback? onCreate;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const CrudButtons({super.key, this.onCreate, this.onView, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (onCreate != null) _CrudBtn('Créer', Icons.add, SM.primary, Colors.white, onCreate!),
      if (onView != null) _CrudBtn('Voir', Icons.visibility_outlined, SM.primarySoft, SM.primary, onView!),
      if (onEdit != null) _CrudBtn('Modifier', Icons.edit_outlined, SM.aiSoft, SM.ai, onEdit!),
      if (onDelete != null) _CrudBtn('Supprimer', Icons.delete_outline, const Color(0xFFFEE2E2), SM.danger, onDelete!),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: items);
  }
}

class _CrudBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg, fg;
  final VoidCallback onTap;
  const _CrudBtn(this.label, this.icon, this.bg, this.fg, this.onTap);

  @override
  Widget build(BuildContext context) => Material(
        color: bg,
        borderRadius: BorderRadius.circular(SM.rButton),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SM.rButton),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(label, style: SM.b(13, color: fg, w: FontWeight.w600)),
            ]),
          ),
        ),
      );
}
