// My route info
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../providers/driver_provider.dart';
import '../../services/nearest_stop.dart' show formatMetres;
import '../../utils/shift_time.dart';

/// My route info widget
class MyRouteInfo extends StatelessWidget {
  /// Create my route info
  const MyRouteInfo({super.key, required this.driver});

  final DriverProvider driver;

  String get _gps {
    if (!driver.onShift) return 'Not on shift';
    return switch (driver.jeepGps) {
      JeepGps.tracker => "From the jeep's tracker",
      JeepGps.phone => 'From your phone (tracker offline)',
      JeepGps.none => 'No GPS right now',
    };
  }

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final vehicle = driver.vehicle;
    final live = driver.live;
    final distance = driver.distanceToNextStopM;
    const label = TextStyle(fontSize: 14, color: AppColors.textSecondary);
    const value = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

    Widget row(String l, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Text(l, style: label),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(v, style: value, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
          ]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'My Route',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          vehicle == null ? 'No vehicle assigned' : '${vehicle.routeCode ?? 'Route'} · ${vehicle.routeLine}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        row('GPS', _gps),
        row('Next Stop', live?.nextStop ?? '—'),
        row('ETA', formatEta(live?.etaNextStop)),
        row('Distance', distance == null ? '—' : formatMetres(distance)),
      ],
    );
  }
}
