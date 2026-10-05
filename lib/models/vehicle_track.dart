import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'vehicle_live_update.dart';

// lib/models/vehicle_track.dart
// Smooths one vehicle's live GPS fixes into continuous marker motion.
//
// Without this the marker jumps to each new fix every 1–3 s. Instead we
// glide from where the marker currently IS to the new fix, over the same
// time the device took between the two fixes (from the backend's "ts").
// The marker trails reality by about one GPS interval, in exchange for
// motion that never teleports.
//
// GPS glitches (multipath near buildings, cold starts) show up as single
// fixes hundreds of metres off. A fix implying an impossible speed is
// dropped; if several in a row agree, the vehicle really did move (e.g.
// it drove on while signal was lost) and we snap to it.

enum TrackResult { animated, snapped, dropped }

class VehicleTrack {
  VehicleTrack(VehicleLiveUpdate first, Duration now)
      : latest = first,
        _from = first.location,
        _to = first.location,
        _fromHeading = first.heading,
        _toHeading = first.heading,
        _start = now,
        _duration = Duration.zero;

  /// Faster than any jeepney; anything above this is a GPS glitch.
  static const double maxPlausibleKmh = 150;

  /// Consecutive implausible fixes needed before accepting a real jump.
  static const int confirmJumpAfter = 3;

  static const Duration minAnimation = Duration(milliseconds: 200);
  static const Duration maxAnimation = Duration(seconds: 5);

  static const Distance _distance = Distance();

  /// Latest accepted state (status, speed, crowd, …).
  VehicleLiveUpdate latest;

  LatLng? _from;
  LatLng? _to;
  double? _fromHeading;
  double? _toHeading;
  Duration _start;
  Duration _duration;
  Duration? _lastFixArrival;
  int _rejectedInARow = 0;

  /// Feeds one live frame. [now] is a monotonic clock (e.g. a Stopwatch).
  TrackResult push(VehicleLiveUpdate update, Duration now) {
    final merged = latest.merge(update);
    if (merged == null) return TrackResult.dropped; // out-of-order fix

    final next = update.location;
    if (next == null) {
      // Status-only frame (signal_lost): marker stays put.
      latest = merged;
      return TrackResult.animated;
    }

    final current = positionAt(now);
    if (current == null) {
      latest = merged;
      _jumpTo(next, update.heading, now);
      return TrackResult.snapped;
    }

    // Measure against the last accepted fix, not the drawn marker: the
    // marker trails by up to one interval and would double the speed.
    final gap = _fixGap(latest, update, now);
    final metres = _distance.as(LengthUnit.Meter, latest.location ?? current, next);
    final impliedKmh = metres / math.max(gap.inMilliseconds / 1000, 0.5) * 3.6;

    if (impliedKmh > maxPlausibleKmh) {
      _rejectedInARow++;
      if (_rejectedInARow < confirmJumpAfter) return TrackResult.dropped;
      latest = merged;
      _jumpTo(next, update.heading, now);
      return TrackResult.snapped;
    }

    _rejectedInARow = 0;
    _fromHeading = headingAt(now);
    _toHeading = update.heading ?? _toHeading;
    _from = current;
    _to = next;
    _start = now;
    _duration = _clamp(gap);
    _lastFixArrival = now;
    latest = merged;
    return TrackResult.animated;
  }

  /// Where the marker should be drawn at [now].
  LatLng? positionAt(Duration now) {
    final from = _from, to = _to;
    if (from == null || to == null) return to ?? from;
    final t = _progress(now);
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  /// Heading to draw at [now], turning the short way round (350° → 10°).
  double? headingAt(Duration now) {
    final from = _fromHeading, to = _toHeading;
    if (from == null || to == null) return to ?? from;
    final delta = ((to - from + 540) % 360) - 180;
    return (from + delta * _progress(now) + 360) % 360;
  }

  bool isAnimating(Duration now) => _progress(now) < 1;

  double _progress(Duration now) {
    if (_duration == Duration.zero) return 1;
    final t = (now - _start).inMicroseconds / _duration.inMicroseconds;
    return t.clamp(0.0, 1.0);
  }

  void _jumpTo(LatLng point, double? heading, Duration now) {
    _rejectedInARow = 0;
    _from = point;
    _to = point;
    _fromHeading = heading;
    _toHeading = heading;
    _start = now;
    _duration = Duration.zero;
    _lastFixArrival = now;
  }

  /// Time between the two fixes: device timestamps when both have one,
  /// otherwise how far apart they arrived here.
  Duration _fixGap(VehicleLiveUpdate prev, VehicleLiveUpdate next, Duration now) {
    final a = prev.timestamp, b = next.timestamp;
    if (a != null && b != null && b.isAfter(a)) return b.difference(a);
    final arrived = _lastFixArrival;
    return arrived != null ? now - arrived : const Duration(seconds: 1);
  }

  static Duration _clamp(Duration d) =>
      d < minAnimation ? minAnimation : (d > maxAnimation ? maxAnimation : d);
}
