// Profile header
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme_config.dart';
import '../../models/commuter_profile.dart';

/// Profile header
class ProfileHeader extends StatelessWidget {
  /// Create profile header
  const ProfileHeader({super.key, required this.profile, required this.onEditName});

  final CommuterProfile profile;
  final VoidCallback onEditName;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final email = profile.email;
    final role = profile.role;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
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
                    ProfileAvatar(initials: profile.initials),
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
                          RoleBadge(label: role[0].toUpperCase() + role.substring(1)),
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
                    const SizedBox(width: 6),
                    _Stat(value: profile.stats.reviews, label: 'Reviews'),
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

/// Profile avatar widget
class ProfileAvatar extends StatelessWidget {
  /// Create profile avatar
  const ProfileAvatar({super.key, required this.initials, this.size = 104});

  final String initials;
  final double size;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Text(
        initials,
        style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }
}

/// Role badge
class RoleBadge extends StatelessWidget {
  /// Create role badge
  const RoleBadge({super.key, required this.label});

  final String label;

  /// Build the widget
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

/// Stat widget
class _Stat extends StatelessWidget {
  /// Create stat
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  /// Build the widget
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
