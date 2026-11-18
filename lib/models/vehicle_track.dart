// Vehicle track
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'vehicle_live_update.dart';


/// Track result options
enum TrackResult { animated, snapped, dropped }

/// Vehicle track
class VehicleTrack {
  /// Create vehicle track
  VehicleTrack(VehicleLiveUpdate first, Duration now)
      : latest = first,
        _from = first.location,
        _to = first.location,
        _fromHeading = first.heading,
        _toHeading = first.heading,
        _headingAnchor = first.location,
        _start = now,
        _duration = Duration.zero;

  static const double maxPlausibleKmh = 150;

  static const int confirmJumpAfter = 3;

  static const double trustGpsHeadingKmh = 15;

  static const double headingMinMoveM = 8;

  static const Duration minAnimation = Duration(milliseconds: 200);
  static const Duration maxAnimation = Duration(seconds: 5);

  static const Distance _distance = Distance();

  VehicleLiveUpdate latest;

  LatLng? _from;
  LatLng? _to;
  double? _fromHeading;
  double? _toHeading;
  LatLng? _headingAnchor;
  Duration _start;
  Duration _duration;
  Duration? _lastFixArrival;
  int _rejectedInARow = 0;

  /// Vehicle track push
  TrackResult push(VehicleLiveUpdate update, Duration now) {
    final merged = latest.merge(update);
    if (merged == null) return TrackResult.dropped;

    final next = update.location;
    if (next == null) {
      latest = merged;
      return TrackResult.animated;
    }

    final current = positionAt(now);
    if (current == null) {
      latest = merged;
      _jumpTo(next, update.heading, now);
      return TrackResult.snapped;
    }

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
    _toHeading = _headingFor(update, next) ?? _toHeading;
    _from = current;
    _to = next;
    _start = now;
    _duration = _clamp(gap);
    _lastFixArrival = now;
    latest = merged;
    return TrackResult.animated;
  }

  /// Position at
  LatLng? positionAt(Duration now) {
    final from = _from, to = _to;
    if (from == null || to == null) return to ?? from;
    final t = _progress(now);
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  /// Heading at
  double? headingAt(Duration now) {
    final from = _fromHeading, to = _toHeading;
    if (from == null || to == null) return to ?? from;
    final delta = ((to - from + 540) % 360) - 180;
    return (from + delta * _progress(now) + 360) % 360;
  }

  /// Is animating?
  bool isAnimating(Duration now) => _progress(now) < 1;

  /// Vehicle track progress
  double _progress(Duration now) {
    if (_duration == Duration.zero) return 1;
    final t = (now - _start).inMicroseconds / _duration.inMicroseconds;
    return t.clamp(0.0, 1.0);
  }

  /// Heading for
  double? _headingFor(VehicleLiveUpdate update, LatLng next) {
    final gps = update.heading, speed = update.speed;
    if (gps != null && (speed == null || speed >= trustGpsHeadingKmh)) {
      _headingAnchor = next;
      return gps;
    }
    final anchor = _headingAnchor;
    if (anchor == null) {
      _headingAnchor = next;
      return null;
    }
    if (_distance.as(LengthUnit.Meter, anchor, next) < headingMinMoveM) return null;
    _headingAnchor = next;
    return (_distance.bearing(anchor, next) + 360) % 360;
  }

  /// Jump to
  void _jumpTo(LatLng point, double? heading, Duration now) {
    _rejectedInARow = 0;
    _headingAnchor = point;
    _from = point;
    _to = point;
    _fromHeading = heading;
    _toHeading = heading;
    _start = now;
    _duration = Duration.zero;
    _lastFixArrival = now;
  }

  /// Fix gap
  Duration _fixGap(VehicleLiveUpdate prev, VehicleLiveUpdate next, Duration now) {
    final a = prev.timestamp, b = next.timestamp;
    if (a != null && b != null && b.isAfter(a)) return b.difference(a);
    final arrived = _lastFixArrival;
    return arrived != null ? now - arrived : const Duration(seconds: 1);
  }

  /// Vehicle track clamp
  static Duration _clamp(Duration d) =>
      d < minAnimation ? minAnimation : (d > maxAnimation ? maxAnimation : d);
}
