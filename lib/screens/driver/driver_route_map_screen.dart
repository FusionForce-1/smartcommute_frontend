// lib/screens/driver/driver_route_map_screen.dart
//
// The dashboard's map, full screen: the driver's route line and stops with
// the jeep on top, and below it the route, where the GPS is coming from,
// and the next stop / ETA. Watches DriverProvider, so it stays live.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../providers/driver_provider.dart';
import '../../utils/shift_time.dart';
import '../../widgets/commuter/commuter_page_header.dart';
import '../../widgets/driver/driver_map.dart';

class DriverRouteMapScreen extends StatelessWidget {
  const DriverRouteMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>();
    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      body: Column(
        children: [
          const CommuterPageHeader(title: 'My Route'),
          Expanded(child: DriverMap(driver: driver)),
          _InfoPanel(driver: driver),
        ],
      ),
    );
  }
}

/// Route, GPS source, and next stop / ETA under the map.
class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.driver});

  final DriverProvider driver;

  String get _gps {
    if (!driver.onShift) return 'Not on shift';
    return switch (driver.jeepGps) {
      JeepGps.tracker => "From the jeep's tracker",
      JeepGps.phone => 'From your phone (tracker offline)',
      JeepGps.none => 'No GPS right now',
    };
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = driver.vehicle;
    final live = driver.live;
    const label = TextStyle(fontSize: 14, color: AppColors.textSecondary);
    const value = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

    Widget row(String l, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Text(l, style: label),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(v, style: value, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
          ]),
        );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                vehicle == null ? 'No vehicle assigned' : '${vehicle.routeCode ?? 'Route'} · ${vehicle.routeLine}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              row('GPS', _gps),
              row('Next stop', live?.nextStop ?? '—'),
              row('ETA', formatEta(live?.etaNextStop)),
            ],
          ),
        ),
      ),
    );
  }
}
