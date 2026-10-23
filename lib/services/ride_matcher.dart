// lib/services/ride_matcher.dart
//
// Which jeep, if any, the commuter is riding — so the map can merge their
// "you are here" dot into that jeep's icon.
//
// On board = one jeep stays within [boardM] of the commuter while they move
// at jeep speed (>= [ridingKmh], walking is ~5 km/h) for [boardAfter]. A
// jeep standing next to someone waiting at the stop isn't enough. Once on
// board they stay merged through traffic stops; they're off once the jeep
// is further than [leaveM] for [leaveAfter] (got off, or a different jeep).

import 'package:latlong2/latlong.dart';

class RideMatcher {
  static const double boardM = 40;
  static const double ridingKmh = 12;
  static const Duration boardAfter = Duration(seconds: 6);
  static const double leaveM = 80;
  static const Duration leaveAfter = Duration(seconds: 10);

  /// Fixes over this window give the commuter's moving speed.
  static const Duration _speedWindow = Duration(seconds: 10);
  static const Distance _d = Distance(roundResult: false);

  final List<({LatLng at, DateTime time})> _fixes = [];
  String? _riding;
  String? _candidate;
  DateTime? _candidateSince;
  DateTime? _farSince;

  /// The jeep being ridden, or null.
  String? get riding => _riding;

  /// Feeds one commuter fix and where every live jeep is now; returns [riding].
  /// [reportedSpeedMps] (the phone's own speed) is used until there's a window of fixes.
  String? update(LatLng here, DateTime at, Map<String, LatLng> jeeps, {double? reportedSpeedMps}) {
    _fixes.add((at: here, time: at));
    _fixes.removeWhere((f) => at.difference(f.time) > _speedWindow);

    final current = _riding;
    if (current != null) {
      final jeep = jeeps[current];
      final far = jeep == null || _d.as(LengthUnit.Meter, here, jeep) > leaveM;
      if (!far) {
        _farSince = null;
        return _riding;
      }
      _farSince ??= at;
      if (at.difference(_farSince!) < leaveAfter) return _riding;
      _riding = null;
      _farSince = null;
      _candidate = null;
    }

    // Nearest jeep close enough to be the one we're in.
    String? nearest;
    var best = double.infinity;
    jeeps.forEach((id, p) {
      final m = _d.as(LengthUnit.Meter, here, p);
      if (m <= boardM && m < best) {
        best = m;
        nearest = id;
      }
    });
    final kmh = _speedKmh(reportedSpeedMps);
    if (nearest == null || kmh == null || kmh < ridingKmh) {
      _candidate = null;
      return null;
    }
    if (_candidate != nearest) {
      _candidate = nearest;
      _candidateSince = at;
    }
    if (at.difference(_candidateSince!) >= boardAfter) {
      _riding = nearest;
      _farSince = null;
    }
    return _riding;
  }

  double? _speedKmh(double? reportedMps) {
    if (_fixes.length >= 2) {
      final first = _fixes.first, last = _fixes.last;
      final seconds = last.time.difference(first.time).inMilliseconds / 1000;
      if (seconds >= 3) {
        var metres = 0.0;
        for (var i = 1; i < _fixes.length; i++) {
          metres += _d.as(LengthUnit.Meter, _fixes[i - 1].at, _fixes[i].at);
        }
        return metres / seconds * 3.6;
      }
    }
    if (reportedMps != null && reportedMps >= 0) return reportedMps * 3.6;
    return null;
  }
}
