import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable card component with soft rounded corners and subtle shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = AppColors.card,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDimensions.anim,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppDimensions.rCard),
        boxShadow: AppDimensions.shadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.rCard),
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

enum AppBadgeType { neutral, success, warning, danger, primary }

/// Reusable badge tag for displaying categories, status, levels, etc.
class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeType type;

  const AppBadge(
    this.label, {
    super.key,
    this.type = AppBadgeType.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (type) {
      AppBadgeType.success => (const Color(0xFFD1FAE5), const Color(0xFF065F46)),
      AppBadgeType.warning => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      AppBadgeType.danger  => (const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
      AppBadgeType.primary => (AppColors.primarySoft, AppColors.primary),
      AppBadgeType.neutral => (const Color(0xFFEEEDF5), AppColors.muted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.rBadge),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Interactive chip widget for filter selections and tags.
class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AppChip(
    this.label, {
    super.key,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.anim,
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.rButton),
          boxShadow: selected ? AppDimensions.shadow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Standard page title banner widget.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const PageHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.muted,
            ),
          ),
        ],
      ],
    );
  }
}

/// Reusable search bar input widget.
class SearchInputField extends StatefulWidget {
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  const SearchInputField({
    super.key,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.onClear,
  });

  @override
  State<SearchInputField> createState() => _SearchInputFieldState();
}

class _SearchInputFieldState extends State<SearchInputField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant SearchInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection =
          TextSelection.collapsed(offset: widget.value.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLength: 50,
      textInputAction: TextInputAction.search,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        counterText: '',
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search, color: AppColors.muted),
        suffixIcon: widget.value.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: AppColors.muted, size: 18),
                onPressed: () {
                  _controller.clear();
                  if (widget.onClear != null) {
                    widget.onClear!();
                  } else {
                    widget.onChanged('');
                  }
                },
              )
            : null,
      ),
    );
  }
}

/// Widget for displaying when a list or search result is empty.
class AppEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;

  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.group_outlined,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.muted,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Displays up to [maxVisible] overlapping circular avatars with initials,
/// then a "+N" overflow indicator.
class OverlappingAvatars extends StatelessWidget {
  final List<({String initials, Color color})> avatars;
  final int maxVisible;
  final double radius;

  const OverlappingAvatars({
    super.key,
    required this.avatars,
    this.maxVisible = 4,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final visible = avatars.take(maxVisible).toList();
    final overflow = avatars.length - visible.length;
    final diameter = radius * 2;
    final overlap = radius * 0.6;
    final totalWidth = visible.isEmpty
        ? 0.0
        : diameter + (visible.length - 1) * (diameter - overlap) +
          (overflow > 0 ? (diameter - overlap) : 0);

    return SizedBox(
      width: totalWidth,
      height: diameter,
      child: Stack(
        children: [
          for (int i = 0; i < visible.length; i++)
            Positioned(
              left: i * (diameter - overlap),
              child: _Avatar(
                initials: visible[i].initials,
                color: visible[i].color,
                radius: radius,
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * (diameter - overlap),
              child: _Avatar(
                initials: '+$overflow',
                color: AppColors.muted,
                radius: radius,
                fontSize: 9,
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  final Color color;
  final double radius;
  final double fontSize;

  const _Avatar({
    required this.initials,
    required this.color,
    required this.radius,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
