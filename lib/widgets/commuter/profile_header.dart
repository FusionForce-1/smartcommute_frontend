// lib/widgets/commuter/profile_header.dart
//
// Teal profile banner: initials avatar, name (with edit button), email,
// role badge and the Trips / Saved Routes counters.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme_config.dart';
import '../../models/commuter_profile.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.profile, required this.onEditName});

  final CommuterProfile profile;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    final email = profile.email;
    final role = profile.role;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // white status-bar icons on teal
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.brandTeal,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppSpacing.lg)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
            child: Column(
              children: [
                Row(
                  children: [
                    _Avatar(initials: profile.initials),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  profile.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit name',
                                onPressed: onEditName,
                                icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.white),
                              ),
                            ],
                          ),
                          if (email != null)
                            Text(
                              email,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, color: Colors.white),
                            ),
                          const SizedBox(height: AppSpacing.xs),
                          _RoleBadge(label: role[0].toUpperCase() + role.substring(1)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _Stat(value: profile.stats.trips, label: 'Trips'),
                    const SizedBox(width: 6),
                    _Stat(value: profile.stats.savedRoutes, label: 'Saved Routes'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Text(
        initials,
        style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
