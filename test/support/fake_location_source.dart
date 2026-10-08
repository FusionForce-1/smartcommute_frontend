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

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }
}
