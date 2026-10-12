// lib/widgets/commuter/nearby_vehicle_card.dart
//
// One row in the Home tab's "Nearby Vehicles" list:
// route code chip, "PUV <code>", route name and an optional ETA.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import 'route_code_chip.dart';

class NearbyVehicleCard extends StatelessWidget {
  const NearbyVehicleCard({
    super.key,
    required this.routeCode,
    required this.routeName,
    this.etaMinutes,
  });

  final String routeCode;
  final String routeName;
  final int? etaMinutes;

  @override
  Widget build(BuildContext context) {
    final eta = etaMinutes;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: Border.all(color: AppColors.divider),
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
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  routeName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                ),
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
    );
  }
}
