// lib/widgets/map_follower.dart
//
// Keeps a map on what moves: the commuter, the driver's jeep, or both at
// once. The camera glides to each new position instead of jumping.
//
// Dragging the map stops it, so people can look around; "Center on my
// location" starts it again. Zooming doesn't stop it, and the zoom they
// picked is kept.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show EdgeInsets;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapFollower {
  MapFollower(this._map, TickerProvider vsync) : _glide = AnimationController(vsync: vsync, duration: glideTime) {
    _glide.addListener(_step);
  }

  static const Duration glideTime = Duration(milliseconds: 600);

  /// Where the camera goes when following starts: street level.
  static const double streetZoom = 16;

  /// Moves smaller than this are GPS jitter, not worth moving the map for.
  static const double minMoveM = 3;

  /// A frame leaves its points this far in from the edge of the map...
  static const double _framePaddingPx = 56;

  /// ...and is redone once one comes this close to it. Less than the padding,
  /// or a point would count as near the edge the moment it was framed.
  static const double _edgeClearancePx = 32;

  static const Set<MapEventSource> _lookingAround = {
    MapEventSource.dragStart,
    MapEventSource.onDrag,
    MapEventSource.keyboard,
  };

  final MapController _map;
  final AnimationController _glide;

  /// True while the camera follows; the locate button shows it.
  final ValueNotifier<bool> following = ValueNotifier(true);

  bool _ready = false;

  /// The next move also goes to street level (or the frame's own zoom).
  bool _fresh = true;

  LatLng _from = const LatLng(0, 0);
  LatLng _to = const LatLng(0, 0);
  double _fromZoom = 0;
  double _toZoom = 0;

  /// The map can be moved from now on.
  void mapReady() => _ready = true;

  void onMapEvent(MapEvent event) {
    if (_lookingAround.contains(event.source)) stop();
  }

  void stop() {
    _glide.stop();
    following.value = false;
  }

  void resume() {
    following.value = true;
    _fresh = true;
  }

  /// Keeps [point] in the middle of the map.
  void center(LatLng point) {
    if (!_ready || !following.value) return;
    final camera = _map.camera;
    final zoom = _fresh ? math.max(camera.zoom, streetZoom) : camera.zoom;
    _fresh = false;
    if (zoom == camera.zoom && const Distance().as(LengthUnit.Meter, camera.center, point) < minMoveM) return;
    _glideTo(point, zoom);
  }

  /// Keeps all of [points] on the map, clear of whatever [covered] says sits
  /// on top of it, reframing only when one nears the edge or they have drawn
  /// much closer together.
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

  void _glideTo(LatLng center, double zoom) {
    final camera = _map.camera;
    _from = camera.center;
    _fromZoom = camera.zoom;
    _to = center;
    _toZoom = zoom;
    _glide.forward(from: 0);
  }

  void _step() {
    final t = Curves.easeOut.transform(_glide.value);
    _map.move(
      LatLng(
        lerpDouble(_from.latitude, _to.latitude, t)!,
        lerpDouble(_from.longitude, _to.longitude, t)!,
      ),
      // Not gliding the zoom: keep whatever the person zooms to meanwhile.
      _fromZoom == _toZoom ? _map.camera.zoom : lerpDouble(_fromZoom, _toZoom, t)!,
    );
  }

  void dispose() {
    _glide.dispose();
    following.dispose();
  }
}
