// Map follower
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show EdgeInsets;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Map follower
class MapFollower {
  /// Create map follower
  MapFollower(this._map, TickerProvider vsync) : _glide = AnimationController(vsync: vsync, duration: glideTime) {
    _glide.addListener(_step);
  }

  static const Duration glideTime = Duration(milliseconds: 600);

  static const double streetZoom = 16;

  static const double minMoveM = 3;

  static const double _framePaddingPx = 56;

  static const double _edgeClearancePx = 32;

  static const Set<MapEventSource> _lookingAround = {
    MapEventSource.dragStart,
    MapEventSource.onDrag,
    MapEventSource.keyboard,
  };

  final MapController _map;
  final AnimationController _glide;

  final ValueNotifier<bool> following = ValueNotifier(true);

  bool _ready = false;

  bool _fresh = true;

  LatLng _from = const LatLng(0, 0);
  LatLng _to = const LatLng(0, 0);
  double _fromZoom = 0;
  double _toZoom = 0;

  /// Map ready
  void mapReady() => _ready = true;

  /// On map event
  void onMapEvent(MapEvent event) {
    if (_lookingAround.contains(event.source)) stop();
  }

  /// Stop map follower
  void stop() {
    _glide.stop();
    following.value = false;
  }

  /// Resume map follower
  void resume() {
    following.value = true;
    _fresh = true;
  }

  /// Center map follower
  void center(LatLng point) {
    if (!_ready || !following.value) return;
    final camera = _map.camera;
    final zoom = _fresh ? math.max(camera.zoom, streetZoom) : camera.zoom;
    _fresh = false;
    if (zoom == camera.zoom && const Distance().as(LengthUnit.Meter, camera.center, point) < minMoveM) return;
    _glideTo(point, zoom);
  }

  /// Map follower frame
  void frame(List<LatLng> points, {EdgeInsets covered = EdgeInsets.zero}) {
    if (!_ready || !following.value || points.isEmpty) return;
    final camera = _map.camera;
    final fitted = CameraFit.coordinates(
      coordinates: points,
      padding: const EdgeInsets.all(_framePaddingPx) + covered,
      maxZoom: 17,
    ).fit(camera);
    final fresh = _fresh;
    _fresh = false;
    if (!fresh && fitted.zoom - camera.zoom < 1 && _wellInView(camera, points, covered)) return;
    _glideTo(fitted.center, fitted.zoom);
  }

  /// Well in view
  static bool _wellInView(MapCamera camera, List<LatLng> points, EdgeInsets covered) {
    final view = camera.visibleBounds;
    final latPerPx = (view.north - view.south) / camera.size.height;
    final lngPerPx = (view.east - view.west) / camera.size.width;
    final north = view.north - (covered.top + _edgeClearancePx) * latPerPx;
    final south = view.south + (covered.bottom + _edgeClearancePx) * latPerPx;
    final east = view.east - (covered.right + _edgeClearancePx) * lngPerPx;
    final west = view.west + (covered.left + _edgeClearancePx) * lngPerPx;
    return points.every((p) =>
        p.latitude < north && p.latitude > south && p.longitude < east && p.longitude > west);
  }

  /// Glide to
  void _glideTo(LatLng center, double zoom) {
    final camera = _map.camera;
    _from = camera.center;
    _fromZoom = camera.zoom;
    _to = center;
    _toZoom = zoom;
    _glide.forward(from: 0);
  }

  /// Step map follower
  void _step() {
    final t = Curves.easeOut.transform(_glide.value);
    _map.move(
      LatLng(
        lerpDouble(_from.latitude, _to.latitude, t)!,
        lerpDouble(_from.longitude, _to.longitude, t)!,
      ),
      _fromZoom == _toZoom ? _map.camera.zoom : lerpDouble(_fromZoom, _toZoom, t)!,
    );
  }

  /// Clean up resources
  void dispose() {
    _glide.dispose();
    following.dispose();
  }
}
