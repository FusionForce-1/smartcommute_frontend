// Commuter header
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';

/// Commuter header
class CommuterHeader extends StatelessWidget {
  /// Create commuter header
  const CommuterHeader({super.key});

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.headerSky,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ClipRect(
              child: Align(
                widthFactor: 1,
                heightFactor: 0.45,
                child: Image.asset(
                  'assets/images/smart_commute_logo_landscape.png',
                  height: 110,
                  semanticLabel: 'Smart Commute',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
