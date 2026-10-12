// lib/widgets/commuter/alert_filter_bar.dart
//
// Scrollable row of filter pills (All / Critical / Warning / Info / Resolved).

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/commuter_alert.dart';

class AlertFilterBar extends StatelessWidget {
  const AlertFilterBar({super.key, required this.selected, required this.onSelected});

  final AlertFilter selected;
  final ValueChanged<AlertFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in AlertFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: _FilterPill(
                label: filter.label,
                selected: filter == selected,
                onTap: () => onSelected(filter),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      side: BorderSide(color: selected ? AppColors.brandTeal : AppColors.divider, width: 1.4),
    );

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.brandTeal : Colors.white,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
