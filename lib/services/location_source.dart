import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationFailure { servicesOff, denied }

class LocationException implements Exception {
  const LocationException(this.reason);

  final LocationFailure reason;

  String get message => switch (reason) {
        LocationFailure.servicesOff => 'Turn on location services to plan a trip.',
        LocationFailure.denied => 'Location permission is needed to plan a trip.',
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

    final position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
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
