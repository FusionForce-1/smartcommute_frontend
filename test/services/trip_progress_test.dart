import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/models/models.dart' show GeoJSONPoint, StopModel;
import 'package:smartcommute_app/models/trip_plan.dart';
import 'package:smartcommute_app/services/trip_progress.dart';

// A 3.3 km jeep line going east along lat 10.300; board at 123.880, alight at 123.910.
const lat = 10.300;
const startLng = 123.880;
const endLng = 123.910;
const mPerDegLng = 111320 * 0.98389; // cos(10.3°)

StopModel stop(String name, double lng) =>
    StopModel(id: name, name: name, sequence: 1, location: GeoJSONPoint(lat: lat, lng: lng));

RouteOption option() => RouteOption(rank: 1, totalEtaMin: 20, totalFare: 13, transfers: 0, legs: [
      RouteLeg(
        routeId: 'r', routeName: '17C', boardStop: stop('Board', startLng), alightStop: stop('Alight', endLng),
        etaMin: 20, fare: 13,
        path: [for (var i = 0; i <= 30; i++) LatLng(lat, startLng + i * 0.001)],
      ),
    ]);

/// Feeds a fix every second, moving east at [kmh] (0 = standing still).
class Sim {
  Sim(this.progress);
  final TripProgress progress;
  DateTime t = DateTime.utc(2026, 10, 21, 8);
  double lng = startLng;
  double offM = 0; // metres north of the line
  TripProgressState? last;

  void go(double kmh, int seconds) {
    for (var i = 0; i < seconds; i++) {
      t = t.add(const Duration(seconds: 1));
      lng += kmh / 3.6 / mPerDegLng;
      last = progress.update(LatLng(lat + offM / 111320, lng), at: t);
    }
  }
}

void main() {
  test('walking along the street is not riding', () {
    final sim = Sim(TripProgress(option(), const {}))..go(5, 60);
    expect(sim.last!.phase, TripPhase.toBoard);
    expect(sim.last!.speedKmh, closeTo(5, 1));
  });

  test('jeep speed on the line becomes riding, and stays riding at a traffic stop', () {
    final sim = Sim(TripProgress(option(), const {}))
      ..go(0, 5)
      ..go(20, 4);
    expect(sim.last!.phase, TripPhase.toBoard, reason: 'a few fast seconds are not enough');
    sim.go(20, 10);
    expect(sim.last!.phase, TripPhase.riding);
    final along = sim.last!.alongM;
    sim.go(0, 90); // stuck in traffic
    expect(sim.last!.phase, TripPhase.riding);
    expect(sim.last!.alongM, along, reason: 'progress never goes back');
    expect(sim.last!.remainingM, lessThan(3300));
  });

  test('close to the alight stop says get off soon, then arrived', () {
    final sim = Sim(TripProgress(option(), const {}))..go(25, 20);
    expect(sim.last!.isRiding, isTrue);
    sim.go(25, ((3300 - sim.last!.alongM - 300) / (25 / 3.6)).round());
    expect(sim.last!.phase, TripPhase.alightSoon);
    sim.go(25, 60);
    expect(sim.last!.phase, TripPhase.arrived);
  });

  test('fast but far from the route is not this jeep', () {
    final sim = Sim(TripProgress(option(), const {}))..offM = 400;
    sim.go(30, 30);
    expect(sim.last!.phase, TripPhase.toBoard);
  });

  test('leaving the line for a while means they got off', () {
    final sim = Sim(TripProgress(option(), const {}))..go(25, 20);
    expect(sim.last!.isRiding, isTrue);
    sim.offM = 200;
    sim.go(4, 30);
    expect(sim.last!.phase, TripPhase.toBoard);
  });

  test('the travelled part of the line splits off', () {
    final progress = TripProgress(option(), const {});
    final sim = Sim(progress)..go(25, 60);
    final split = progress.split(0);
    expect(split.done.first, const LatLng(lat, startLng));
    expect(split.ahead.last, const LatLng(lat, endLng));
    expect(const Distance().as(LengthUnit.Meter, split.done.last, split.ahead.first), lessThan(1));
    expect(split.done.last.longitude, closeTo(sim.lng, 0.0005));
  });
}
