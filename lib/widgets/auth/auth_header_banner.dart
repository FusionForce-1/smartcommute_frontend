// lib/widgets/auth/auth_header_banner.dart
//
// Teal curved banner shared by ForgotPasswordScreen, VerifyOtpScreen and
// RegisterScreen. Icons come from AppIcons (not inline Icons.xxx).

import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';

class AuthHeaderBanner extends StatelessWidget {
  const AuthHeaderBanner({
    super.key,
    required this.title,
    this.onBack,
    this.big = false,
    this.centerTitle = false,
  });

  final String title;
  final VoidCallback? onBack;

  /// [big] renders the large two-line "FORGOT / PASSWORD" title.
  final bool big;

  /// Register mockup centers "CREATE YOUR ACCOUNT" on the banner.
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        MediaQuery.of(context).padding.top + AppSpacing.xs,
        AppSpacing.sm,
        big ? AppSpacing.lg : AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bannerTeal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.bannerCurve),
          bottomRight: Radius.circular(AppRadius.bannerCurve),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(AppIcons.back, color: Colors.white, size: 20),
            ),
          ),
          if (centerTitle)
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: 22,
                    letterSpacing: 0.8,
                  ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                title,
                style: big
                    ? Theme.of(context).textTheme.headlineLarge
                    : Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontSize: 22),
              ),
            ),
        ],
      ),
    );
  }
}
