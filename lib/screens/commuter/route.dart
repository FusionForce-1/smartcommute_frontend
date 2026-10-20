// lib/screens/commuter/route.dart
//
// Route tab — "Plan Your Route": choose From / To, departure time and a
// preference, then Find Routes opens the results page. State lives in
// TripPlanProvider (owned by the dashboard), so results survive tab changes.

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../models/transport_model.dart';
import '../../models/transport_stop.dart';
import '../../providers/trip_plan_provider.dart';
import '../../widgets/commuter/commuter_field_box.dart';
import '../../widgets/commuter/commuter_primary_button.dart';
import '../../widgets/commuter/preference_selector.dart';
import '../../widgets/commuter/recent_searches.dart';
import '../../widgets/commuter/trip_locations_card.dart';
import '../../config/map_config.dart';
import '../../widgets/place_search_sheet.dart';
import 'find_routes_screen.dart';
import 'pick_destination_screen.dart';
import 'route_map_screen.dart' show VehiclesLoader;

class RouteTab extends StatelessWidget {
  const RouteTab({super.key, required this.stops, required this.routes, this.onTripStarted, this.loadVehicles});

  final List<TransportStop> stops;
  final List<TransportRoute> routes;

  /// Called when the commuter opens a chosen route on the map.
  final TripStarted? onTripStarted;

  /// Fleet list for the live jeeps on a chosen route's map.
  final VehiclesLoader? loadVehicles;

  // From / To search every saved stop and Metro Cebu landmark as you type,
  // nearest the trip's other end (or the city centre) first.
  Future<void> _chooseFrom(BuildContext context) async {
    final trip = context.read<TripPlanProvider>();
    final place = await showPlaceSearchSheet(
      context,
      stops: stops,
      title: 'Where are you starting from?',
      near: trip.destination ?? trip.origin ?? MapConfig.defaultCenter,
    );
    if (place == null || !context.mounted) return;
    trip.setOrigin(place.location, place.name);
  }

  Future<void> _chooseTo(BuildContext context) async {
    final trip = context.read<TripPlanProvider>();
    final place = await showPlaceSearchSheet(
      context,
      stops: stops,
      title: 'Where are you going?',
      near: trip.origin ?? MapConfig.defaultCenter,
    );
    if (place == null || !context.mounted) return;
    trip.setDestination(place.location, place.name);
  }

  Future<void> _pickOnMap(BuildContext context) async {
    final trip = context.read<TripPlanProvider>();
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => PickDestinationScreen(origin: trip.origin)),
    );
    if (picked == null) return;
    trip.setDestination(
      picked,
      'Dropped pin (${picked.latitude.toStringAsFixed(4)}, '
      '${picked.longitude.toStringAsFixed(4)})',
    );
  }

  Future<void> _findRoutes(BuildContext context) async {
    final trip = context.read<TripPlanProvider>();
    // No From chosen yet: start from the commuter's GPS location.
    if (trip.origin == null) await trip.locateOrigin();
    if (!context.mounted || !trip.canPlan) return; // error shows under From

    trip.plan(); // the results page shows progress
    Navigator.of(context).push(
      MaterialPageRoute(
        // A pushed page sits outside the dashboard's provider scope.
        builder: (_) => ChangeNotifierProvider.value(
          value: trip,
          child: FindRoutesScreen(routes: routes, onTripStarted: onTripStarted, loadVehicles: loadVehicles),
        ),
      ),
    );
  }

  void _changeDepartureTime(BuildContext context) {
    // The backend plans for "now" only; scheduled trips need API support.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scheduling a later departure is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripPlanProvider>();
    final canFind = trip.destination != null &&
        !trip.isLocating &&
        trip.status != TripPlanStatus.loading;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const Center(
          child: Text(
            'Plan Your Route',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TripLocationsCard(
          fromValue: trip.isLocating
              ? 'Finding your location…'
              : trip.originLabel ?? (trip.origin != null ? 'Your location' : null),
          toValue: trip.destinationLabel,
          isLocating: trip.isLocating,
          fromError: trip.locationError,
          onOpenSettings: trip.canOpenLocationSettings ? trip.openLocationSettings : null,
          onChooseFrom: () => _chooseFrom(context),
          onUseMyLocation: trip.locateOrigin,
          onSwap: trip.canSwap ? trip.swapOriginAndDestination : null,
          onChooseTo: () => _chooseTo(context),
          onPickOnMap: () => _pickOnMap(context),
        ),
        const SizedBox(height: AppSpacing.md),
        const _SectionTitle(icon: Icons.schedule, title: 'Departure Time'),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            const Expanded(child: CommuterFieldBox(hint: 'Leave now', value: 'Leave now')),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => _changeDepartureTime(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: AppColors.textPrimary,
                textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w400),
                side: const BorderSide(color: AppColors.divider, width: 1.4),
              ),
              child: const Text('Change'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const _SectionTitle(title: 'Preference'),
        const SizedBox(height: AppSpacing.xs),
        PreferenceSelector(selected: trip.preference, onSelected: trip.setPreference),
        const SizedBox(height: AppSpacing.md),
        RecentSearches(
          places: trip.recentSearches,
          onSelected: (place) => trip.setDestination(place.location, place.label),
        ),
        const SizedBox(height: AppSpacing.sm),
        CommuterPrimaryButton(
          label: 'Find Routes',
          onPressed: canFind ? () => _findRoutes(context) : null,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 28, color: AppColors.textPrimary),
          const SizedBox(width: AppSpacing.xs),
        ],
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
