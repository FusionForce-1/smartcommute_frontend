// Nearby vehicle card
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../services/boarding_planner.dart' show formatKm;
import 'route_code_chip.dart';

/// Nearby vehicle card
class NearbyVehicleCard extends StatelessWidget {
  /// Create nearby vehicle card
  const NearbyVehicleCard({
    super.key,
    required this.routeCode,
    required this.routeName,
    this.etaMinutes,
    this.etaCaption,
    this.passed = false,
    this.distanceM,
    this.delayed = false,
    this.selected = false,
    this.onTap,
  });

  final String routeCode;
  final String routeName;
  final int? etaMinutes;

  final String? etaCaption;

  final bool passed;

  final double? distanceM;

  final bool delayed;

  final bool selected;
  final VoidCallback? onTap;

  /// Format distance
  static String formatDistance(double metres) => '${formatKm(metres)} away';

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final eta = etaMinutes;
    final distance = distanceM;
    final radius = BorderRadius.circular(AppSpacing.xs);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: selected ? AppColors.headerSky : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? AppColors.brandTeal : AppColors.divider, width: selected ? 1.6 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          RouteCodeChip(code: routeCode),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              'PUV $routeCode',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (delayed) ...[
                            const SizedBox(width: AppSpacing.xs),
                            const Text(
                              'Delayed',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.accent),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        routeName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                      ),
                      if (distance != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          formatDistance(distance),
                          style: const TextStyle(fontSize: 13, color: AppColors.navInactive),
                        ),
                      ],
                    ],
                  ),
                ),
                if (passed)
                  const Text('Passed you', style: TextStyle(fontSize: 14, color: AppColors.navInactive))
                else if (eta != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '~$eta min',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.brandTeal,
                        ),
                      ),
                      if (etaCaption case final caption?)
                        Text(caption, style: const TextStyle(fontSize: 12, color: AppColors.navInactive)),
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
