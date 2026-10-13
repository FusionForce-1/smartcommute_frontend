// lib/widgets/commuter/commuter_action_tile.dart
//
// Full-width white card with a teal icon and a label, used for the
// dashboard's quick actions ("Center on my location", "Sign out", ...).

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';

class CommuterActionTile extends StatelessWidget {
  const CommuterActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.textPrimary : AppColors.navInactive;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          side: const BorderSide(color: AppColors.divider),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 20,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: enabled ? AppColors.brandTeal : AppColors.navInactive,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
