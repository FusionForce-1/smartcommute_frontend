// Route screen
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../models/selected_trip.dart';
import '../../models/transport_model.dart';
import '../../models/transport_stop.dart';
import '../../providers/trip_plan_provider.dart';
import '../../services/nearest_stop.dart';
import '../../widgets/commuter/commuter_primary_button.dart';
import '../../widgets/commuter/preference_selector.dart';
import '../../widgets/commuter/recent_searches.dart';
import '../../widgets/commuter/trip_locations_card.dart';
import '../../config/map_config.dart';
import '../../widgets/place_search_sheet.dart';
import 'find_routes_screen.dart';
import 'pick_destination_screen.dart';
import 'route_map_screen.dart' show VehiclesLoader;

/// Route tab
class RouteTab extends StatelessWidget {
  /// Create route tab
  const RouteTab({
    super.key,
    required this.stops,
    required this.routes,
    this.onTripStarted,
    this.onRouteSelected,
    this.loadVehicles,
  });

  final List<TransportStop> stops;
  final List<TransportRoute> routes;

  final TripStarted? onTripStarted;

  final TripSelected? onRouteSelected;

  final VehiclesLoader? loadVehicles;

  /// Choose from
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

  /// Choose to
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

  /// Pick on map
  Future<void> _pickOnMap(BuildContext context) async {
    final trip = context.read<TripPlanProvider>();
    final picked = await Navigator.of(context).push<PickedPlace>(
      MaterialPageRoute(
        builder: (_) => PickDestinationScreen(
          origin: trip.origin,
          stops: stops,
          start: trip.destinationFromMap ? trip.destination : null,
        ),
      ),
    );
    if (picked == null) return;
    trip.setDestination(picked.point, picked.label, fromMap: true);
  }

  /// Find routes
  Future<void> _findRoutes(BuildContext context) async {
    final trip = context.read<TripPlanProvider>();
    if (trip.origin == null) await trip.locateOrigin();
    if (!context.mounted || !trip.canPlan) return;

    trip.plan();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: trip,
          child: FindRoutesScreen(
            routes: routes,
            onTripStarted: onTripStarted,
            onRouteSelected: onRouteSelected,
            loadVehicles: loadVehicles,
          ),
        ),
      ),
    );
  }

  /// My location label
  String _myLocationLabel(LatLng here) {
    final near = nearestStop(stops, here);
    return near == null ? 'Your location' : 'Your location · near ${near.stop.name}';
  }

  /// Build the widget
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
              : trip.originLabel ?? (trip.origin != null ? _myLocationLabel(trip.origin!) : null),
          toValue: trip.destinationLabel,
          isLocating: trip.isLocating,
          usingMyLocation: trip.origin != null && trip.originLabel == null,
          destinationOnMap: trip.destinationFromMap,
          fromError: trip.locationError,
          onOpenSettings: trip.canOpenLocationSettings ? trip.openLocationSettings : null,
          onChooseFrom: () => _chooseFrom(context),
          onUseMyLocation: trip.locateOrigin,
          onSwap: trip.canSwap ? trip.swapOriginAndDestination : null,
          onChooseTo: () => _chooseTo(context),
          onPickOnMap: () => _pickOnMap(context),
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

/// Section title widget
class _SectionTitle extends StatelessWidget {
  /// Create section title
  const _SectionTitle({required this.title});

  final String title;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
    );
  }
}
