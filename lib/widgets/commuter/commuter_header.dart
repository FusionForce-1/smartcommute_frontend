// lib/widgets/commuter/commuter_header.dart
//
// Sky-blue banner with the landscape logo across the top of the commuter
// dashboard. Extends under the status bar.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';

class CommuterHeader extends StatelessWidget {
  const CommuterHeader({super.key});

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
            // The PNG has wide blank margins above and below the artwork;
            // clip to the middle band so the banner stays slim.
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
