// lib/screens/driver/driver_dashboard_view.dart
//
// The Driver Dashboard: the map with the jeep and its route, the shift
// (started and ended by the operator; crowd and passengers while it runs),
// the driver's routes, and their updates. Reads DriverProvider from above.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../providers/driver_provider.dart';
import '../../providers/load_state.dart';
import '../../widgets/commuter/commuter_header.dart';
import '../../widgets/driver/crowd_estimate_card.dart';
import '../../widgets/driver/driver_map.dart';
import '../../widgets/driver/driver_profile_card.dart';
import '../../widgets/driver/my_routes_card.dart';
import '../../widgets/driver/shift_card.dart';
import '../../widgets/driver/updates_card.dart';
import 'driver_route_map_screen.dart';

class DriverDashboardView extends StatelessWidget {
  const DriverDashboardView({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      body: Column(
        children: [
          const CommuterHeader(),
          Expanded(
            child: switch (driver.loadState) {
              LoadState.idle || LoadState.loading => const Center(child: CircularProgressIndicator()),
              LoadState.error => _LoadError(message: driver.loadError, onRetry: driver.load),
              LoadState.ready => RefreshIndicator(
                  onRefresh: driver.refresh,
                  child: _DashboardBody(driver: driver, onSignOut: onSignOut),
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.driver, required this.onSignOut});

  final DriverProvider driver;
  final VoidCallback onSignOut;

  /// Runs a provider action and shows the message it returns, if any.
  Future<void> _report(BuildContext context, Future<String?> Function() action) async {
    final messenger = ScaffoldMessenger.of(context); // before the await
    final message = await action();
    if (message == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openMap(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(value: driver, child: const DriverRouteMapScreen()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final shift = driver.shift;
    const gap = SizedBox(height: AppSpacing.sm);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.lg),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Driver Dashboard',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
              ),
            ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: onSignOut,
              icon: const Icon(Icons.logout, color: AppColors.textSecondary),
            ),
          ],
        ),
        gap,
        DriverProfileCard(name: driver.name, vehicle: driver.vehicle),
        gap,
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 260,
            child: DriverMap(driver: driver, onExpand: () => _openMap(context)),
          ),
        ),
        gap,
        ShiftCard(
          shift: shift,
          vehicle: driver.vehicle,
          jeepGps: driver.jeepGps,
          gpsError: driver.gpsError,
          onRetryGps: driver.retryPhoneGps,
          onPassengerChange: (change) => _report(context, () => driver.changePassengers(change)),
        ),
        if (shift != null) ...[
          gap,
          CrowdEstimateCard(
            percent: driver.crowdPercent,
            onChanged: driver.previewCrowd,
            onChangeEnd: (percent) => _report(context, () => driver.commitCrowd(percent)),
          ),
        ],
        gap,
        MyRoutesCard(vehicles: driver.vehicles, shiftVehicleId: shift?.vehicleId, live: driver.live),
        gap,
        UpdatesCard(updates: driver.updates, onMarkAllRead: driver.markUpdatesRead),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.navInactive),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message ?? "Couldn't load your dashboard.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.brandTeal),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
