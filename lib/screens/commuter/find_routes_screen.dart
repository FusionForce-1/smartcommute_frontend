// lib/screens/commuter/find_routes_screen.dart
//
// "Find Routes" page, opened from Plan Your Route: shows the trip-plan
// request's progress, then the ranked route options. The best option
// starts selected; tap another to select it, then view it on the map.
// While open, the plan follows the commuter's GPS (TripPlanProvider live
// updates): the closest stop and the next jeep refresh as they move.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../models/transport_model.dart';
import '../../models/trip_plan.dart';
import '../../providers/trip_plan_provider.dart';
import '../../widgets/commuter/commuter_page_header.dart';
import '../../widgets/commuter/commuter_primary_button.dart';
import '../../widgets/commuter/route_option_card.dart';
import 'route_map_screen.dart';

/// A route option the commuter chose to follow, between two place names.
typedef TripStarted = void Function(RouteOption option, String from, String to);

class FindRoutesScreen extends StatefulWidget {
  const FindRoutesScreen({super.key, required this.routes, this.onTripStarted, this.loadVehicles});

  /// Routes from /routes, for route codes, stop counts and map lines.
  final List<TransportRoute> routes;

  /// Called when the selected route is opened on the map (records a trip).
  final TripStarted? onTripStarted;

  /// Fleet list, so the map can show the jeeps live on the chosen route.
  final VehiclesLoader? loadVehicles;

  @override
  State<FindRoutesScreen> createState() => _FindRoutesScreenState();
}

class _FindRoutesScreenState extends State<FindRoutesScreen> {
  // Held so dispose() doesn't need a context.
  TripPlanProvider? _trip;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_trip == null) {
      _trip = context.read<TripPlanProvider>();
      // After this frame: starting notifies listeners, which can't happen mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _trip?.startLiveUpdates();
      });
    }
  }

  @override
  void dispose() {
    _trip?.stopLiveUpdates();
    super.dispose();
  }

  void _viewOnMap(BuildContext context, RouteOption option, Map<String, TransportRoute> routesById) {
    final trip = context.read<TripPlanProvider>();
    widget.onTripStarted?.call(option, trip.originLabel ?? 'Your location', trip.destinationLabel ?? 'Destination');
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RouteMapScreen(option: option, routesById: routesById, loadVehicles: widget.loadVehicles)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripPlanProvider>();
    final routesById = {for (final route in widget.routes) route.id: route};
    final selected = trip.selectedOption;

    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      body: Column(
        children: [
          const CommuterPageHeader(title: 'Find Routes'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const Text(
                  'Route Options',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.black),
                ),
                Text(
                  '${trip.originLabel ?? 'Your location'} → ${trip.destinationLabel ?? ''}',
                  style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                ),
                if (trip.isFollowingLocation) _LiveStatus(trip: trip),
                if (trip.updateNotice != null)
                  _UpdateNotice(text: trip.updateNotice!, onDismiss: trip.dismissUpdateNotice),
                const SizedBox(height: AppSpacing.md),
                ...switch (trip.status) {
                  TripPlanStatus.idle || TripPlanStatus.loading => [
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  TripPlanStatus.empty => [
                      const _StatusMessage(
                        icon: AppIcons.emptyState,
                        text: 'No route found to this destination.',
                      ),
                    ],
                  TripPlanStatus.error => [
                      _StatusMessage(
                        icon: AppIcons.errorRetry,
                        text: trip.errorMessage ?? 'Something went wrong. Please try again.',
                        color: AppColors.error,
                        onRetry: trip.canPlan ? trip.plan : null,
                      ),
                    ],
                  TripPlanStatus.success => [
                      for (final option in trip.options)
                        RouteOptionCard(
                          option: option,
                          routesById: routesById,
                          selected: identical(option, selected),
                          onTap: () => trip.selectOption(option),
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      CommuterPrimaryButton(
                        label: 'View Selected Route on Map',
                        onPressed: selected == null
                            ? null
                            : () => _viewOnMap(context, selected, routesById),
                      ),
                    ],
                },
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveStatus extends StatelessWidget {
  const _LiveStatus({required this.trip});

  final TripPlanProvider trip;

  @override
  Widget build(BuildContext context) {
    final updated = trip.lastUpdated;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(AppIcons.myLocation, size: 16, color: AppColors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              updated == null
                  ? 'Following your location'
                  : 'Following your location  •  Updated ${TimeOfDay.fromDateTime(updated).format(context)}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          if (trip.isRefreshing)
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }
}

class _UpdateNotice extends StatelessWidget {
  const _UpdateNotice({required this.text, required this.onDismiss});

  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundIceBlue,
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
      child: Row(
        children: [
          const Icon(Icons.update, size: 18, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Dismiss',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.text,
    this.color = AppColors.textSecondary,
    this.onRetry,
  });

  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final onRetry = this.onRetry;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(height: AppSpacing.xs),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 15)),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}
