// lib/widgets/commuter/saved_route_tile.dart
//
// One saved route on the Profile tab: bookmark icon, route code, label
// ("Home → Office") and the stops it runs between.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/commuter_profile.dart';
import 'route_code_chip.dart';

class SavedRouteTile extends StatelessWidget {
  const SavedRouteTile({
    super.key,
    required this.route,
    required this.onTap,
    required this.onLongPress,
  });

  final SavedRoute route;
  final VoidCallback onTap;

  /// Offers to remove the saved route.
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 12, AppSpacing.xs, 12),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.brandTeal,
                  child: Icon(Icons.bookmark_border, color: Colors.white),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          RouteCodeChip(code: route.routeCode ?? '—'),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              route.label,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${route.originName} → ${route.destinationName}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
