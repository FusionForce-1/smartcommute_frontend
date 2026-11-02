// lib/widgets/commuter/commuter_nav_bar.dart
//
// Bottom navigation for the commuter dashboard: the selected tab is a
// filled teal tile, the others are grey icon + label. A tab can show a dot
// (e.g. unread notifications).

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';

class CommuterNavItem {
  const CommuterNavItem({required this.icon, required this.label, this.showDot = false});

  final IconData icon;
  final String label;
  final bool showDot;
}

class CommuterNavBar extends StatelessWidget {
  const CommuterNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<CommuterNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final CommuterNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.navInactive;

    return Semantics(
      button: true,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: selected ? AppColors.brandTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Badge(
                    isLabelVisible: item.showDot,
                    smallSize: 9,
                    backgroundColor: AppColors.error,
                    child: Icon(item.icon, size: 28, color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
