import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/models/vehicle_live_update.dart';
import 'package:smartcommute_app/models/vehicle_track.dart';

const _distance = Distance();
final _t0 = DateTime.utc(2026, 9, 30, 4);

VehicleLiveUpdate fix(double lat, double lng, int secs, {double? heading}) =>
    VehicleLiveUpdate(
      vehicleId: 'v1',
      status: 'en_route',
      location: LatLng(lat, lng),
      heading: heading,
      timestamp: _t0.add(Duration(seconds: secs)),
    );

double metres(LatLng a, LatLng b) => _distance.as(LengthUnit.Meter, a, b);

void main() {
  test('marker glides between fixes — no frame jumps more than a few metres', () {
    // Jeep at ~36 km/h (10 m/s), a fix every 2 s = 20 m between fixes.
    const stepDeg = 20 / 111320; // 20 m of latitude
    final track = VehicleTrack(fix(10.3, 123.9, 0), Duration.zero);

    const frame = Duration(microseconds: 16667); // 60 fps
    var now = Duration.zero;
    var last = track.positionAt(now)!;
    var maxStep = 0.0;

    for (var i = 1; i <= 10; i++) {
      track.push(fix(10.3 + stepDeg * i, 123.9, i * 2), now);
      final end = now + const Duration(seconds: 2);
      while (now < end) {
        now += frame;
        final p = track.positionAt(now)!;
        final step = metres(last, p);
        if (step > maxStep) maxStep = step;
        last = p;
      }
    }

    // 20 m over 2 s at 60 fps ≈ 0.17 m per frame. Anything near 20 m
    // would be a teleport.
    expect(maxStep, lessThan(0.5));
    expect(metres(last, LatLng(10.3 + stepDeg * 10, 123.9)), lessThan(0.5));
  });

  test('new fix mid-animation continues from the drawn position', () {
    const stepDeg = 20 / 111320;
    final track = VehicleTrack(fix(10.3, 123.9, 0), Duration.zero);
    track.push(fix(10.3 + stepDeg, 123.9, 2), Duration.zero);

    // Halfway through, the next fix arrives early.
    const mid = Duration(seconds: 1);
    final before = track.positionAt(mid)!;
    track.push(fix(10.3 + stepDeg * 2, 123.9, 4), mid);
    final after = track.positionAt(mid)!;

    expect(metres(before, after), lessThan(0.01));
  });

  test('single GPS glitch is ignored', () {
    final track = VehicleTrack(fix(10.3, 123.9, 0), Duration.zero);
    // 2 km away 1 s later = 7200 km/h.
    final r = track.push(fix(10.318, 123.9, 1), const Duration(seconds: 1));
    expect(r, TrackResult.dropped);
    expect(metres(track.positionAt(const Duration(seconds: 2))!,
            const LatLng(10.3, 123.9)),
        lessThan(0.01));
  });

  test('a real jump (confirmed by consecutive fixes) snaps once', () {
    final track = VehicleTrack(fix(10.3, 123.9, 0), Duration.zero);
    TrackResult? r;
    for (var i = 1; i <= VehicleTrack.confirmJumpAfter; i++) {
      r = track.push(fix(10.318, 123.9, i), Duration(seconds: i));
    }
    expect(r, TrackResult.snapped);
    expect(metres(track.positionAt(const Duration(seconds: 3))!,
            const LatLng(10.318, 123.9)),
        lessThan(0.01));
  });

  test('heading turns the short way round', () {
    final track = VehicleTrack(fix(10.3, 123.9, 0, heading: 350), Duration.zero);
    track.push(fix(10.30001, 123.9, 2, heading: 10), Duration.zero);
    final mid = track.headingAt(const Duration(seconds: 1))!;
    expect(mid, closeTo(0, 0.5)); // not 180
  });

  test('stale fix does not pull the marker backwards', () {
    final track = VehicleTrack(fix(10.3, 123.9, 10), Duration.zero);
    expect(track.push(fix(10.2999, 123.9, 5), Duration.zero), TrackResult.dropped);
  });

  test('signal_lost keeps the marker where it was', () {
    final track = VehicleTrack(fix(10.3, 123.9, 0), Duration.zero);
    track.push(
      const VehicleLiveUpdate(vehicleId: 'v1', status: 'signal_lost'),
      const Duration(seconds: 1),
    );
    expect(track.latest.isSignalLost, isTrue);
    expect(track.positionAt(const Duration(seconds: 1)), const LatLng(10.3, 123.9));
  });
}
