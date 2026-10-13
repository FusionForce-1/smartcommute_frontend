// lib/widgets/commuter/preference_selector.dart
//
// Three equal-width toggles (Fastest / Cheapest / Few Transfers);
// the chosen one is filled teal.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/trip_plan.dart';

class PreferenceSelector extends StatelessWidget {
  const PreferenceSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final TripPreference selected;
  final ValueChanged<TripPreference> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final preference in TripPreference.values) ...[
          if (preference != TripPreference.values.first) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _PreferenceButton(
              label: preference.label,
              selected: preference == selected,
              onTap: () => onSelected(preference),
            ),
          ),
        ],
      ],
    );
  }
}

class _PreferenceButton extends StatelessWidget {
  const _PreferenceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.brandTeal : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? AppColors.brandTeal : AppColors.divider, width: 1.4),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 46,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
