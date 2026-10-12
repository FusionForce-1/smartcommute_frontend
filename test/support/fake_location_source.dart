import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/services/location_source.dart';

class FakeLocationSource implements LocationSource {
  FakeLocationSource({this.result, this.failure, this.canOpenSettings = true});

  LatLng? result;
  LocationFailure? failure;
  int settingsOpened = 0;

  @override
  final bool canOpenSettings;

  @override
  Future<LatLng> currentLocation() async {
    final failure = this.failure;
    if (failure != null) throw LocationException(failure);
    return result!;
  }

  /// Push positions with `positions.add(...)` to simulate the commuter moving.
  final StreamController<LatLng> positions = StreamController<LatLng>.broadcast();

  @override
  Stream<LatLng> positionStream({int distanceFilterM = 25}) => positions.stream;

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }
}
