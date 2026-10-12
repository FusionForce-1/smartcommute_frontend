// lib/screens/commuter/route.dart
//
// Route tab: open the Trip Planner, revisit the last fare estimate, and
// browse every active route.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../models/transport_model.dart';
import '../../models/transport_stop.dart';
import '../../providers/trip_plan_provider.dart';
import '../../widgets/commuter/commuter_action_tile.dart';
import '../../widgets/commuter/route_code_chip.dart';
import '../../widgets/fare_breakdown_sheet.dart';
import 'trip_planner_screen.dart';

class RouteTab extends StatelessWidget {
  const RouteTab({super.key, required this.stops, required this.routes});

  final List<TransportStop> stops;
  final List<TransportRoute> routes;

  void _openPlanner(BuildContext context) {
    // The planner is a new page, outside the dashboard's provider scope,
    // so hand it the same TripPlanProvider to keep its results here.
    final trip = context.read<TripPlanProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: trip,
          child: TripPlannerScreen(stops: stops),
        ),
      ),
    );
  }

  void _showFareEstimate(BuildContext context) {
    final option = context.read<TripPlanProvider>().selectedOption;
    if (option == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan a trip and pick a route to see its fare.')),
      );
      return;
    }
    showFareBreakdownSheet(context, option);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        CommuterActionTile(
          icon: AppIcons.search,
          label: 'Plan a trip',
          onTap: () => _openPlanner(context),
        ),
        CommuterActionTile(
          icon: AppIcons.fare,
          label: 'View fare estimate',
          onTap: () => _showFareEstimate(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Available Routes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (routes.isEmpty)
          const Text('No routes available yet.')
        else
          for (final route in routes) _RouteCard(route: route),
      ],
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route});

  final TransportRoute route;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          RouteCodeChip(code: route.code),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              route.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            ),
          ),
          Text(
            '${route.stops.length} stops',
            style: const TextStyle(fontSize: 13, color: AppColors.navInactive),
          ),
        ],
      ),
    );
  }
}
