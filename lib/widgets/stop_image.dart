// Stop image
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../config/env_config.dart';
import '../config/theme_config.dart';
import '../models/transport_stop.dart';

/// Stop image URLs
class StopImageUrls {
  /// Create stop image
  StopImageUrls._();

  /// Street view
  static String? streetView(LatLng location, {int size = 400}) {
    final key = EnvConfig.googleMapsApiKey;
    if (key == null) return null;
    return 'https://maps.googleapis.com/maps/api/streetview'
        '?size=${size}x$size'
        '&location=${location.latitude},${location.longitude}'
        '&fov=90&source=outdoor&return_error_code=true'
        '&key=$key';
  }

  static const String satelliteTiles =
      'https://server.arcgisonline.com/ArcGIS/rest/services/'
      'World_Imagery/MapServer/tile/{z}/{y}/{x}';

  static ({String url, Offset position}) satelliteTile(LatLng location, {int zoom = 18}) {
    final n = math.pow(2, zoom).toDouble();
    final lat = location.latitude * math.pi / 180;
    final x = (location.longitude + 180) / 360 * n;
    final y = (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * n;
    final url = satelliteTiles
        .replaceFirst('{z}', '$zoom')
        .replaceFirst('{y}', '${y.floor()}')
        .replaceFirst('{x}', '${x.floor()}');
    return (url: url, position: Offset(x - x.floor(), y - y.floor()));
  }
}

/// Stop image
class StopImage extends StatelessWidget {
  /// Create stop image
  const StopImage({
    super.key,
    required this.location,
    this.size = 400,
    this.fit = BoxFit.cover,
  });

  final LatLng location;

  final int size;
  final BoxFit fit;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final satellite = _satellite();

    final streetViewUrl = StopImageUrls.streetView(location, size: size);
    if (streetViewUrl == null) return satellite;

    return _network(streetViewUrl, onError: satellite);
  }

  /// Stop image network
  Widget _network(String url, {required Widget onError}) {
    return Image.network(
      url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppColors.backgroundIceBlue,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => onError,
    );
  }

  /// Stop image satellite
  Widget _satellite() {
    return AbsorbPointer(
      child: FlutterMap(
        options: MapOptions(
          initialCenter: location,
          initialZoom: 18,
          backgroundColor: AppColors.backgroundIceBlue,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: StopImageUrls.satelliteTiles,
            userAgentPackageName: 'com.smartcommute.app',
            maxNativeZoom: 19,
          ),
        ],
      ),
    );
  }
}

/// Stop image marker
class StopImageMarker extends StatelessWidget {
  /// Create stop image marker
  const StopImageMarker({
    super.key,
    required this.stop,
    this.onTap,
    this.photo = maxPhoto,
  });

  static const double maxPhoto = 28;
  static const double _pointerHeight = 6;

  /// Width for
  static double widthFor(double photo) => photo + 4;
  /// Height for
  static double heightFor(double photo) => photo + _pointerHeight;

  final TransportStop stop;
  final VoidCallback? onTap;

  final double photo;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: stop.name,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: photo,
              height: photo,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.secondary, width: 2),
                boxShadow: AppShadows.card,
                color: Colors.white,
              ),
              child: ClipOval(child: _StopThumbnail(location: stop.location)),
            ),
            CustomPaint(
              size: const Size(10, _pointerHeight),
              painter: _PointerPainter(AppColors.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stop thumbnail widget
class _StopThumbnail extends StatelessWidget {
  /// Create stop thumbnail
  const _StopThumbnail({required this.location});

  static const double _tileSize = 256;

  final LatLng location;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final satellite = LayoutBuilder(
      builder: (context, constraints) {
        final tile = StopImageUrls.satelliteTile(location);
        double align(double fraction, double extent) =>
            ((fraction * _tileSize - extent / 2) / (_tileSize - extent) * 2 - 1)
                .clamp(-1.0, 1.0);
        return Image.network(
          tile.url,
          fit: BoxFit.none,
          alignment: Alignment(
            align(tile.position.dx, constraints.maxWidth),
            align(tile.position.dy, constraints.maxHeight),
          ),
          errorBuilder: (context, error, stackTrace) =>
              const ColoredBox(color: AppColors.backgroundIceBlue),
        );
      },
    );

    final streetViewUrl = StopImageUrls.streetView(location, size: 150);
    if (streetViewUrl == null) return satellite;
    return Image.network(
      streetViewUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => satellite,
    );
  }
}

/// Pointer painter
class _PointerPainter extends CustomPainter {
  /// Create pointer painter
  const _PointerPainter(this.color);

  final Color color;

  /// Paint the canvas
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// Repaint when changed
  @override
  bool shouldRepaint(_PointerPainter oldDelegate) => oldDelegate.color != color;
}

/// Show stop details sheet
Future<void> showStopDetailsSheet(BuildContext context, TransportStop stop) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final height = math.min(
                    constraints.maxWidth * 10 / 16,
                    MediaQuery.sizeOf(context).height * 0.35,
                  );
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: height,
                      child: StopImage(
                        location: stop.location,
                        size: 640,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(stop.name, style: textTheme.titleMedium),
              if (stop.landmark != null && stop.landmark!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Near ${stop.landmark}',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '${stop.location.latitude.toStringAsFixed(5)}, '
                '${stop.location.longitude.toStringAsFixed(5)}',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    },
  );
}
