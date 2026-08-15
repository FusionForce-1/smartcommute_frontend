// lib/widgets/auth/smart_commute_logo.dart
//
// NOT one of the 11 official E3 reusable widgets — this is a small
// screen-composition helper used only by the auth flow (Login / Register),
// matching the logo lockup + tagline shown centered in those mockups.

import 'package:flutter/material.dart';
import '../../config/theme_config.dart';

class SmartCommuteLogo extends StatelessWidget {
  const SmartCommuteLogo({
    super.key,
    this.height = 140,
    this.showTagline = true,
    this.taglineColor,
  });

  final double height;
  final bool showTagline;
  final Color? taglineColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/smart_commute_logo.png',
          height: height,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.location_on,
            size: height * 0.6,
            color: AppColors.accent,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            'Cebu City Transit Information',
            style: TextStyle(
              color: taglineColor ?? AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }
}
