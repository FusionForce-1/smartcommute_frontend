// Route code chip
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';

/// Route code chip
class RouteCodeChip extends StatelessWidget {
  /// Create route code chip
  const RouteCodeChip({super.key, required this.code, this.compact = false});

  final String code;
  final bool compact;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : AppSpacing.sm, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: AppColors.brandTeal,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(code, style: TextStyle(fontSize: compact ? 12 : 14, color: Colors.white)),
    );
  }
}
