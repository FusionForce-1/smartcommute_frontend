// Ride matcher
import 'package:latlong2/latlong.dart';

/// Ride matcher
class RideMatcher {
  static const double boardM = 40;
  static const double ridingKmh = 12;
  static const Duration boardAfter = Duration(seconds: 6);
  static const double leaveM = 80;
  static const Duration leaveAfter = Duration(seconds: 10);

  static const Duration _speedWindow = Duration(seconds: 10);
  static const Distance _d = Distance(roundResult: false);

  final List<({LatLng at, DateTime time})> _fixes = [];
  String? _riding;
  String? _candidate;
  DateTime? _candidateSince;
  DateTime? _farSince;

  String? get riding => _riding;

  /// Update ride matcher
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

  /// Speed kmh
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
