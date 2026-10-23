import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/services/ride_matcher.dart';

const lat = 10.300;
const mPerDegLng = 111320 * 0.98389;

/// The commuter and jeeps along lat 10.300, a fix every second.
class Sim {
  final m = RideMatcher();
  DateTime t = DateTime.utc(2026, 10, 23, 8);
  double me = 123.880;
  double jeep = 123.880;
  String? last;

  /// [meKmh] / [jeepKmh] east; [gapM] how far east of the commuter the jeep is.
  void go(int seconds, {required double meKmh, double? jeepKmh, double gapM = 5}) {
    for (var i = 0; i < seconds; i++) {
      t = t.add(const Duration(seconds: 1));
      me += meKmh / 3.6 / mPerDegLng;
      jeep = jeepKmh == null ? me + gapM / mPerDegLng : jeep + jeepKmh / 3.6 / mPerDegLng;
      last = m.update(LatLng(lat, me), t, {'jeep1': LatLng(lat, jeep), 'far': const LatLng(lat, 123.95)});
    }
  }
}

void main() {
  test('waiting next to a parked jeep is not riding it', () {
    final sim = Sim()..go(30, meKmh: 0);
    expect(sim.last, isNull);
  });

  test('moving with a jeep at jeep speed for a few seconds is riding it', () {
    final sim = Sim()..go(4, meKmh: 20);
    expect(sim.last, isNull, reason: 'a few seconds is not enough');
    sim.go(6, meKmh: 20);
    expect(sim.last, 'jeep1');
  });

  test('stays merged through a traffic stop', () {
    final sim = Sim()..go(12, meKmh: 20);
    sim.go(60, meKmh: 0);
    expect(sim.last, 'jeep1');
  });

  test('walking away from the jeep after getting off un-merges', () {
    final sim = Sim()..go(12, meKmh: 20);
    expect(sim.last, 'jeep1');
    sim.go(35, meKmh: 4, jeepKmh: 25);   // the jeep drives on, we walk (80 m apart after ~13 s, then 10 s)
    expect(sim.last, isNull);
  });

  test('a fast ride with no jeep nearby (e.g. a taxi) merges with nothing', () {
    final sim = Sim()..go(20, meKmh: 30, gapM: 300);
    expect(sim.last, isNull);
  });
}
