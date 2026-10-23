// lib/screens/driver/driver_dashboard_view.dart
//
// The Driver Dashboard screen: profile, GPS broadcast, assigned route,
// route status, crowd estimate, and the shift (START SHIFT, or the Shift
// Active card with END SHIFT). Reads DriverProvider from above.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../providers/driver_provider.dart';
import '../../providers/load_state.dart';
import '../../widgets/commuter/commuter_header.dart';
import '../../widgets/driver/assigned_route_card.dart';
import '../../widgets/driver/crowd_estimate_card.dart';
import '../../widgets/driver/driver_buttons.dart';
import '../../widgets/driver/driver_profile_card.dart';
import '../../widgets/driver/end_shift_sheet.dart';
import '../../widgets/driver/gps_broadcast_card.dart';
import '../../widgets/driver/route_status_card.dart';
import '../../widgets/driver/shift_active_card.dart';
import 'driver_route_map_screen.dart';
import 'shift_complete_screen.dart';

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
                  onRefresh: driver.load,
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

  Future<void> _endShift(BuildContext context) async {
    final shift = driver.shift;
    if (shift == null) return;
    if (!await showEndShiftSheet(context, startedAt: shift.startedAt)) return;

    final result = await driver.endShift();
    if (!context.mounted) return;
    final summary = result.summary;
    if (summary == null) return _report(context, () async => result.error);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ShiftCompleteScreen(summary: summary)),
    );
  }

  void _openMap(BuildContext context, {required bool followMe}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: driver,
        child: DriverRouteMapScreen(service: driver.service, followMe: followMe),
      ),
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
        GpsBroadcastCard(
          session: driver.gps,
          onChanged: (on) => _report(context, () => driver.setBroadcasting(on)),
          onViewLive: () => _openMap(context, followMe: true),
        ),
        gap,
        AssignedRouteCard(
          vehicles: driver.vehicles,
          vehicle: driver.vehicle,
          live: driver.live,
          locked: driver.onShift,
          onVehicleSelected: driver.selectVehicle,
        ),
        gap,
        RouteStatusCard(
          selected: driver.dutyStatus,
          onSelected: (status) => _report(context, () => driver.setDutyStatus(status)),
        ),
        gap,
        CrowdEstimateCard(
          percent: driver.crowdPercent,
          onChanged: driver.previewCrowd,
          onChangeEnd: (percent) => _report(context, () => driver.commitCrowd(percent)),
        ),
        const SizedBox(height: AppSpacing.md),
        if (shift == null)
          StartShiftButton(
            busy: driver.busy,
            onPressed: driver.vehicle == null ? null : () => _report(context, driver.startShift),
          )
        else
          ShiftActiveCard(
            shift: shift,
            distanceKm: driver.distanceKm,
            onPassengerChange: (change) => _report(context, () => driver.changePassengers(change)),
            onEndShift: driver.busy ? null : () => _endShift(context),
          ),
        const SizedBox(height: AppSpacing.md),
        ViewRouteButton(onPressed: () => _openMap(context, followMe: false)),
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
