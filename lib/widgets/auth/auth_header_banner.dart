// lib/widgets/auth/auth_header_banner.dart
//
// NOT one of the 11 official E3 reusable widgets — screen-composition helper
// shared by ForgotPasswordScreen, VerifyOtpScreen and RegisterScreen: the
// solid teal banner with a rounded bottom edge, back chevron, and title.

import 'package:flutter/material.dart';
import '../../config/theme_config.dart';

class AuthHeaderBanner extends StatelessWidget {
  const AuthHeaderBanner({
    super.key,
    required this.title,
    this.onBack,
    this.big = false,
  });

  final String title;
  final VoidCallback? onBack;

  /// [big] renders the large two-line "FORGOT / PASSWORD"-style title used on
  /// ForgotPasswordScreen / VerifyOtpScreen. When false, renders the smaller
  /// single-line uppercase title style used on RegisterScreen.
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        MediaQuery.of(context).padding.top + AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bannerTeal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.bannerCurve),
          bottomRight: Radius.circular(AppRadius.bannerCurve),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            style: big
                ? Theme.of(context).textTheme.headlineLarge
                : Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 22),
          ),
        ],
      ),
    );
  }
}
