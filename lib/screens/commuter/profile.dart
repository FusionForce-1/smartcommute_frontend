// lib/screens/commuter/profile.dart
//
// Profile tab: account settings and sign-out. Guests see a notice and
// the account actions stay disabled.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../widgets/commuter/commuter_action_tile.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.isGuest, required this.onSignOut});

  final bool isGuest;

  /// Logs out and returns to the login screen (handled by the dashboard).
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (isGuest) const _GuestNotice(),
        CommuterActionTile(
          icon: AppIcons.settings,
          label: 'Account settings',
          enabled: !isGuest,
          onTap: () {
            // TODO [Velez]: open the account settings screen.
          },
        ),
        CommuterActionTile(
          icon: AppIcons.logout,
          label: 'Sign out',
          onTap: onSignOut,
        ),
      ],
    );
  }
}

class _GuestNotice extends StatelessWidget {
  const _GuestNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: const Text(
        'Guest mode — sign in to access profile and saved trips.',
        style: TextStyle(color: AppColors.error, fontSize: 13),
      ),
    );
  }
}
