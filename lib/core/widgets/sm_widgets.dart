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
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  const SearchField(this.hint, {super.key, this.onChanged, this.controller});
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.search, color: SM.muted)),
      );
}
