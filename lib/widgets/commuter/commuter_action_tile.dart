// Commuter action tile
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';

/// Commuter action tile
class CommuterActionTile extends StatelessWidget {
  /// Create commuter action tile
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

  /// Build the widget
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
