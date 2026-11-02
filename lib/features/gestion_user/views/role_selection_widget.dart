
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

class RoleSelectionWidget extends StatelessWidget {
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;

  const RoleSelectionWidget({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleCard(
            title: 'Étudiant',
            subtitle: 'Réviser et apprendre',
            icon: LucideIcons.graduationCap,
            selected: selectedRole == 'student',
            onTap: () => onRoleChanged('student'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RoleCard(
            title: 'Enseignant',
            subtitle: 'Partager ses cours',
            icon: LucideIcons.bookOpen,
            selected: selectedRole == 'teacher',
            onTap: () => onRoleChanged('teacher'),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SM.rCard),
      child: AnimatedContainer(
        duration: SM.anim,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? SM.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(SM.rCard),
          border: Border.all(
            color: selected ? SM.primary : Colors.black12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 30,
              color: selected ? SM.primary : SM.muted,
            ),
            const SizedBox(height: 8),
            Text(title, style: SM.b(15, w: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: SM.b(11, color: SM.muted),
            ),
            if (selected) ...[
              const SizedBox(height: 8),
              const Icon(
                LucideIcons.circleCheck,
                color: SM.primary,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
