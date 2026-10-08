// lib/screens/commuter/trip_planner_screen.dart
//
// Trip Planner: From = GPS location sa commuter, To = stop o pin sa map.
// Results gikan sa backend POST /trip-plan; i-tap ang option para sa fare breakdown.

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../models/transport_stop.dart';
import '../../models/trip_plan.dart';
import '../../providers/trip_plan_provider.dart';
import '../../widgets/fare_breakdown_sheet.dart';
import '../../widgets/stop_search_sheet.dart';
import 'pick_destination_screen.dart';

class TripPlannerScreen extends StatefulWidget {
  const TripPlannerScreen({super.key, required this.stops});

  /// Stops gikan sa /stops (gi-load na sa dashboard).
  final List<TransportStop> stops;

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  @override
  void initState() {
    super.initState();
    // I-refresh ang GPS kada abli sa planner
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TripPlanProvider>().locateOrigin();
    });
  }

  Future<void> _chooseStop() async {
    final stop = await showStopSearchSheet(context, widget.stops);
    if (stop == null || !mounted) return;
    context.read<TripPlanProvider>().setDestination(stop.location, stop.name);
  }

  Future<void> _pickOnMap() async {
    final trip = context.read<TripPlanProvider>();
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => PickDestinationScreen(origin: trip.origin),
      ),
    );
    if (picked == null || !mounted) return;
    trip.setDestination(
      picked,
      'Dropped pin (${picked.latitude.toStringAsFixed(4)}, '
      '${picked.longitude.toStringAsFixed(4)})',
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripPlanProvider>();
    final isLoading = trip.status == TripPlanStatus.loading;

    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Plan a trip'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _OriginCard(trip: trip),
          const SizedBox(height: AppSpacing.xs),
          _DestinationCard(
            label: trip.destinationLabel,
            onSearch: _chooseStop,
            onPickOnMap: _pickOnMap,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final preference in TripPreference.values)
                ChoiceChip(
                  label: Text(preference.label),
                  selected: trip.preference == preference,
                  onSelected: (_) => trip.setPreference(preference),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: trip.canPlan ? trip.plan : null,
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(AppIcons.search),
            label: const Text('Find routes'),
          ),
          const SizedBox(height: AppSpacing.md),
          _Results(trip: trip),
        ],
      ),
    );
  }
}

class _OriginCard extends StatelessWidget {
  const _OriginCard({required this.trip});

  final TripPlanProvider trip;

  @override
  Widget build(BuildContext context) {
    final origin = trip.origin;
    final error = trip.locationError;

    final String subtitle;
    if (trip.isLocating) {
      subtitle = 'Finding your location…';
    } else if (error != null) {
      subtitle = error;
    } else if (origin == null) {
      subtitle = 'Location not set';
    } else {
      subtitle = '${origin.latitude.toStringAsFixed(4)}, '
          '${origin.longitude.toStringAsFixed(4)}';
    }

    return _PlannerCard(
      child: ListTile(
        leading: const Icon(AppIcons.myLocation, color: AppColors.secondary),
        title: const Text('From: My location'),
        subtitle: Text(
          subtitle,
          style: error != null ? const TextStyle(color: AppColors.error) : null,
        ),
        trailing: trip.isLocating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null && trip.canOpenLocationSettings)
                    IconButton(
                      tooltip: 'Open settings',
                      icon: const Icon(AppIcons.settings),
                      onPressed: trip.openLocationSettings,
                    ),
                  IconButton(
                    tooltip: 'Refresh location',
                    icon: const Icon(AppIcons.errorRetry),
                    onPressed: trip.locateOrigin,
                  ),
                ],
              ),
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.label,
    required this.onSearch,
    required this.onPickOnMap,
  });

  final String? label;
  final VoidCallback onSearch;
  final VoidCallback onPickOnMap;

  @override
  Widget build(BuildContext context) {
    return _PlannerCard(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(AppIcons.location, color: AppColors.error),
            title: Text(label == null ? 'To: Choose a destination' : 'To: $label'),
            trailing: const Icon(AppIcons.search),
            onTap: onSearch,
          ),
          const Divider(height: 1),
          TextButton.icon(
            onPressed: onPickOnMap,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Pick on map'),
          ),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.trip});

  final TripPlanProvider trip;

  @override
  Widget build(BuildContext context) {
    return switch (trip.status) {
      TripPlanStatus.idle => const _Message(
          icon: AppIcons.search,
          text: 'Choose a destination, then tap Find routes.',
        ),
      TripPlanStatus.loading => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Center(child: CircularProgressIndicator()),
        ),
      TripPlanStatus.empty => const _Message(
          icon: AppIcons.emptyState,
          text: 'No route found to this destination.',
        ),
      TripPlanStatus.error => _Message(
          icon: AppIcons.errorRetry,
          text: trip.errorMessage ?? 'Something went wrong. Please try again.',
          color: AppColors.error,
        ),
      TripPlanStatus.success => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Route options', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            for (final option in trip.options)
              _OptionCard(
                option: option,
                selected: identical(trip.selectedOption, option),
                onTap: () {
                  trip.selectOption(option);
                  showFareBreakdownSheet(context, option);
                },
              ),
          ],
        ),
    };
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final RouteOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color: selected
              ? AppColors.primary
              : AppColors.secondary.withValues(alpha: 0.2),
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: Text('${option.rank}'),
        ),
        title: Text(option.routeSummary),
        subtitle: Text(
          '${option.totalEtaMin} min · ${formatTransfers(option.transfers)}',
        ),
        trailing: Text(
          formatFare(option.totalFare),
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Icon(icon, color: tint, size: 36),
          const SizedBox(height: AppSpacing.xs),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: tint)),
        ],
      ),
    );
  }
}

class _PlannerCard extends StatelessWidget {
  const _PlannerCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }
}
