// Commuter field box
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';

/// Commuter field box
class CommuterFieldBox extends StatelessWidget {
  /// Create commuter field box
  const CommuterFieldBox({
    super.key,
    required this.hint,
    this.value,
    this.onTap,
  });

  final String hint;
  final String? value;
  final VoidCallback? onTap;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final value = this.value;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppColors.divider, width: 1.4),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
          child: Text(
            value ?? hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              color: value == null ? AppColors.navInactive : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
