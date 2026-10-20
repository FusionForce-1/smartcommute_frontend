import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationFailure { servicesOff, denied, unavailable, timeout }

class LocationException implements Exception {
  const LocationException(this.reason);

  final LocationFailure reason;

  String get message => switch (reason) {
        LocationFailure.servicesOff => 'Turn on location services to plan a trip.',
        LocationFailure.denied => 'Location permission is needed to plan a trip.',
        // Browsers (Brave especially) rely on the computer's own location
        // setting; with it off they report "position unavailable".
        LocationFailure.unavailable => kIsWeb
            ? "Your browser couldn't find where you are. Turn on location for this "
                'device (Windows: Settings › Privacy & security › Location), or tap '
                'the From box to choose a starting point.'
            : "Couldn't get a location fix. Turn on Wi-Fi or move near a window, or "
                'tap the From box to choose a starting point.',
        LocationFailure.timeout => 'Finding your location took too long. Try again, or '
            'tap the From box to choose a starting point.',
      };
}

/// Gi-abstract ang GPS para ma-test ang TripPlanProvider nga walay Geolocator.
abstract class LocationSource {
  Future<LatLng> currentLocation();

  /// Position updates while the commuter moves at least [distanceFilterM].
  /// Permission is checked by [currentLocation] first, so this assumes it.
  Stream<LatLng> positionStream({int distanceFilterM = 25});

  Future<void> openSettings();

  /// False kung dili ma-abli ang settings (e.g. web — mo-throw ang geolocator).
  bool get canOpenSettings;
}

class GeolocatorLocationSource implements LocationSource {
  /// How long the precise (GPS) attempt gets before falling back.
  static const Duration _preciseLimit = Duration(seconds: 8);

  /// How long the quick (Wi-Fi / network) fallback gets.
  static const Duration _quickLimit = Duration(seconds: 10);

  @override
  bool get canOpenSettings => !kIsWeb;

  @override
  Future<LatLng> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationFailure.servicesOff);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationException(LocationFailure.denied);
    }

    // Precise first; indoors or on a laptop without GPS that can fail or
    // never come, so fall back to a quicker, approximate fix.
    try {
      return await _position(LocationAccuracy.high, _preciseLimit);
    } on LocationException catch (e) {
      if (e.reason == LocationFailure.denied) rethrow;
    }
    return _position(LocationAccuracy.low, _quickLimit);
  }

  /// One position lookup, with the platform's errors turned into
  /// [LocationException]s the planner can explain.
  Future<LatLng> _position(LocationAccuracy accuracy, Duration limit) async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy, timeLimit: limit),
      );
      return LatLng(p.latitude, p.longitude);
    } on PermissionDeniedException {
      throw const LocationException(LocationFailure.denied);
    } on LocationServiceDisabledException {
      throw const LocationException(LocationFailure.servicesOff);
    } on TimeoutException {
      throw const LocationException(LocationFailure.timeout);
    } on PositionUpdateException {
      throw const LocationException(LocationFailure.unavailable);
    }
  }

  @override
  Stream<LatLng> positionStream({int distanceFilterM = 25}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterM,
      ),
    ).map((p) => LatLng(p.latitude, p.longitude));
  }

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}
