// Trip progress
import 'package:latlong2/latlong.dart';

import '../models/models.dart' show StopModel;
import '../models/trip_plan.dart';
import '../models/transport_model.dart';
import 'boarding_planner.dart';

/// Trip phase options
enum TripPhase {
  toBoard,

  riding,

  alightSoon,

  arrived,
}

/// Trip progress state
class TripProgressState {
  /// Create trip progress
  const TripProgressState({
    required this.phase,
    required this.legIndex,
    required this.alongM,
    required this.remainingM,
    required this.speedKmh,
  });

  final TripPhase phase;

  final int legIndex;

  final double alongM;

  final double remainingM;

  final double? speedKmh;

  bool get isRiding => phase == TripPhase.riding || phase == TripPhase.alightSoon;
}

/// Trip progress
class TripProgress {
  /// Create trip progress
  TripProgress(this.option, Map<String, TransportRoute> routesById)
      : _legs = [
          for (final leg in option.legs) _LegLine.of(leg, leg.path ?? routesById[leg.routeId]?.geometry ?? const []),
        ];

  final RouteOption option;
  final List<_LegLine> _legs;

  static const double ridingKmh = 12;

  static const Duration ridingAfter = Duration(seconds: 6);

  static const double onLineM = 50;

  static const double offLineM = 120;
  static const Duration leaveAfter = Duration(seconds: 25);

  static const double alightSoonM = 350;

  static const double arrivedM = 60;

  static const Duration _speedWindow = Duration(seconds: 12);

  final List<({LatLng at, DateTime time})> _fixes = [];
  int _leg = 0;
  bool _riding = false;
  bool _arrived = false;
  double _along = 0;
  DateTime? _fastSince;
  DateTime? _offSince;

  TripProgressState? _state;
  TripProgressState? get state => _state;

  /// Update trip progress
  TripProgressState update(LatLng here, {required DateTime at, double? reportedSpeedMps}) {
    _fixes.add((at: here, time: at));
    _fixes.removeWhere((f) => at.difference(f.time) > _speedWindow);
    final kmh = _speedKmh(reportedSpeedMps);

    if (_arrived || _legs.isEmpty) return _set(kmh);
    final leg = _legs[_leg];
    final pos = leg.line.length >= 2 ? projectOnLine(leg.line, here) : null;
    final offset = pos?.offsetM ?? double.infinity;
    final along = pos?.alongM ?? 0;

    if (!_riding) {
      final fast = kmh != null && kmh >= ridingKmh && offset <= onLineM && along >= leg.boardAlong - onLineM;
      if (fast) {
        _fastSince ??= at;
        if (at.difference(_fastSince!) >= ridingAfter) {
          _riding = true;
          _offSince = null;
          _along = along;
        }
      } else {
        _fastSince = null;
      }
    } else {
      if (offset <= onLineM && along > _along) _along = along;
      if (offset > offLineM) {
        _offSince ??= at;
        if (at.difference(_offSince!) >= leaveAfter) {
          _riding = false;
          _fastSince = null;
        }
      } else {
        _offSince = null;
      }
    }

    final atAlight = (_riding && leg.alightAlong - _along <= arrivedM) ||
        (leg.alight != null && const Distance(roundResult: false).as(LengthUnit.Meter, here, leg.alight!) <= arrivedM && _along > 0);
    if (atAlight) {
      if (_leg == _legs.length - 1) {
        _arrived = true;
        _along = leg.alightAlong;
      } else {
        _leg++;
        _riding = false;
        _fastSince = null;
        _along = 0;
      }
    }
    return _set(kmh);
  }

  /// Trip progress boarded
  TripProgressState boarded(LatLng here, {required DateTime at}) {
    final kmh = _state?.speedKmh;
    if (_arrived || _riding || _legs.isEmpty) return _state ?? _set(kmh);
    final leg = _legs[_leg];
    final pos = leg.line.length >= 2 ? projectOnLine(leg.line, here) : null;
    if (pos == null || pos.offsetM > offLineM) return _state ?? _set(kmh);
    _riding = true;
    _offSince = null;
    _along = pos.alongM;
    return _set(kmh);
  }

  /// Line of
  List<LatLng> lineOf(int legIndex) => _legs[legIndex].line;

  /// Set trip progress
  TripProgressState _set(double? kmh) {
    final leg = _legs.isEmpty ? null : _legs[_leg];
    final remaining = leg == null ? 0.0 : (leg.alightAlong - _along).clamp(0.0, double.infinity);
    final phase = _arrived
        ? TripPhase.arrived
        : !_riding
            ? TripPhase.toBoard
            : remaining <= alightSoonM
                ? TripPhase.alightSoon
                : TripPhase.riding;
    return _state = TripProgressState(
      phase: phase,
      legIndex: _leg,
      alongM: _along,
      remainingM: remaining.toDouble(),
      speedKmh: kmh,
    );
  }

  /// Speed kmh
  double? _speedKmh(double? reportedMps) {
    if (_fixes.length >= 2) {
      final first = _fixes.first, last = _fixes.last;
      final seconds = last.time.difference(first.time).inMilliseconds / 1000;
      if (seconds >= 3) {
        var metres = 0.0;
        for (var i = 1; i < _fixes.length; i++) {
          metres += const Distance(roundResult: false).as(LengthUnit.Meter, _fixes[i - 1].at, _fixes[i].at);
        }
        return metres / seconds * 3.6;
      }
    }
    if (reportedMps != null && reportedMps >= 0) return reportedMps * 3.6;
    return null;
  }

  ({List<LatLng> done, List<LatLng> ahead}) split(int legIndex) {
    final leg = _legs[legIndex];
    final line = leg.line;
    final s = _state;
    if (line.length < 2 || s == null) return (done: const [], ahead: line);
    if (legIndex < s.legIndex || s.phase == TripPhase.arrived) return (done: line, ahead: const []);
    if (legIndex > s.legIndex || s.alongM <= 0) return (done: const [], ahead: line);
    final cut = _pointAt(line, s.alongM);
    final done = [for (var i = 0; i <= cut.segment; i++) line[i], cut.point];
    final ahead = [cut.point, for (var i = cut.segment + 1; i < line.length; i++) line[i]];
    return (done: done, ahead: ahead);
  }

  static ({LatLng point, int segment}) _pointAt(List<LatLng> line, double along) {
    const d = Distance(roundResult: false);
    var walked = 0.0;
    for (var i = 0; i < line.length - 1; i++) {
      final len = d.as(LengthUnit.Meter, line[i], line[i + 1]);
      if (walked + len >= along) {
        final t = len == 0 ? 0.0 : (along - walked) / len;
        final a = line[i], b = line[i + 1];
        return (
          point: LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t),
          segment: i,
        );
      }
      walked += len;
    }
    return (point: line.last, segment: line.length - 2);
  }
}

/// Leg line
class _LegLine {
  /// Create leg line
  _LegLine(this.line, this.boardAlong, this.alightAlong, this.alight);

  /// Create of leg line
  factory _LegLine.of(RouteLeg leg, List<LatLng> line) {
    LatLng? at(StopModel stop) => stop.isPlaceholder ? null : LatLng(stop.location.lat, stop.location.lng);
    final board = at(leg.boardStop);
    final alight = at(leg.alightStop);
    final total = _length(line);
    final boardAlong = board == null || line.length < 2 ? 0.0 : projectOnLine(line, board)!.alongM;
    final alightAlong = alight == null || line.length < 2 ? total : projectOnLine(line, alight)!.alongM;
    return _LegLine(line, boardAlong, alightAlong, alight);
  }

  final List<LatLng> line;
  final double boardAlong;
  final double alightAlong;
  final LatLng? alight;

  /// Leg line length
  static double _length(List<LatLng> line) {
    const d = Distance(roundResult: false);
    var m = 0.0;
    for (var i = 0; i < line.length - 1; i++) {
      m += d.as(LengthUnit.Meter, line[i], line[i + 1]);
    }
    return m;
  }
}
