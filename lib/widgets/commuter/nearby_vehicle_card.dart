// lib/widgets/commuter/nearby_vehicle_card.dart
//
// One row in the Home tab's "Nearby Vehicles" list:
// route code chip, "PUV <code>", route name and an optional ETA.
// When [onTap] is set the row is selectable (draws the vehicle → you line
// on the Live Map); [selected] highlights the vehicle being shown.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import 'route_code_chip.dart';

class NearbyVehicleCard extends StatelessWidget {
  const NearbyVehicleCard({
    super.key,
    required this.routeCode,
    required this.routeName,
    this.etaMinutes,
    this.distanceM,
    this.delayed = false,
    this.selected = false,
    this.onTap,
  });

  final String routeCode;
  final String routeName;
  final int? etaMinutes;

  /// Straight-line distance from the commuter, when their location is known.
  final double? distanceM;

  /// The driver set their Route Status to Delayed.
  final bool delayed;

  final bool selected;
  final VoidCallback? onTap;

  static String formatDistance(double metres) =>
      metres < 1000 ? '${metres.round()} m away' : '${(metres / 1000).toStringAsFixed(1)} km away';

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
                if (eta != null)
                  Text(
                    '~$eta min',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.brandTeal,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
