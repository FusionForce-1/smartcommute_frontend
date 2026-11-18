// Commuter location source

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationFailure { servicesOff, denied, unavailable, timeout }

/// Location lookup failure
class LocationException implements Exception {
  /// Create location failure
  const LocationException(this.reason);

  final LocationFailure reason;

  String get message => switch (reason) {
        LocationFailure.servicesOff => 'Turn on location services to plan a trip.',
        LocationFailure.denied => 'Location permission is needed to plan a trip.',
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

/// Location source interface
abstract class LocationSource {
  /// Get current location
  Future<LatLng> currentLocation();

  /// Stream position updates
  Stream<LatLng> positionStream({int distanceFilterM = 25});

  /// Open app settings
  Future<void> openSettings();

  bool get canOpenSettings;
}

/// Geolocator location source
class GeolocatorLocationSource implements LocationSource {
  static const Duration _preciseLimit = Duration(seconds: 8);

  static const Duration _quickLimit = Duration(seconds: 10);

  @override
  bool get canOpenSettings => !kIsWeb;

  /// Get current location
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

    try {
      return await _position(LocationAccuracy.high, _preciseLimit);
    } on LocationException catch (e) {
      if (e.reason == LocationFailure.denied) rethrow;
    }
    return _position(LocationAccuracy.low, _quickLimit);
  }

  /// One position lookup
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

  /// Stream position updates
  @override
  Stream<LatLng> positionStream({int distanceFilterM = 25}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterM,
      ),
    ).map((p) => LatLng(p.latitude, p.longitude));
  }

  /// Open app settings
  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}
