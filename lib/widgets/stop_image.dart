// lib/widgets/stop_image.dart
//
// Shows a real photo of the area around a Transport Stop based on its
// coordinates, so commuters can recognize the place right away.
//
// Image sources (tried in order):
//   1. Google Street View Static API — only if GOOGLE_MAPS_API_KEY is in .env
//   2. Esri World Imagery satellite snapshot centered on the stop (free, no key)
//   3. Fallback icon if both images fail to load

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../config/env_config.dart';
import '../config/theme_config.dart';
import '../models/transport_stop.dart';

class StopImageUrls {
  StopImageUrls._();

  /// Street-level photo of the stop. Returns null if no API key is set.
  /// `return_error_code=true` makes Google return 404 when there's no
  /// Street View coverage, so we fall back to the satellite image.
  static String? streetView(LatLng location, {int size = 400}) {
    final key = EnvConfig.googleMapsApiKey;
    if (key == null) return null;
    return 'https://maps.googleapis.com/maps/api/streetview'
        '?size=${size}x$size'
        '&location=${location.latitude},${location.longitude}'
        '&fov=90&source=outdoor&return_error_code=true'
        '&key=$key';
  }

  /// Satellite snapshot centered on the stop (about 120m x 120m of area).
  static String satellite(LatLng location, {int size = 400}) {
    const halfMeters = 60.0;
    final dLat = halfMeters / 111320;
    final dLng =
        halfMeters / (111320 * math.cos(location.latitude * math.pi / 180));
    final bbox = [
      location.longitude - dLng,
      location.latitude - dLat,
      location.longitude + dLng,
      location.latitude + dLat,
    ].join(',');
    return 'https://server.arcgisonline.com/ArcGIS/rest/services/'
        'World_Imagery/MapServer/export'
        '?bbox=$bbox&bboxSR=4326&imageSR=3857'
        '&size=$size,$size&format=jpg&f=image';
  }
}

/// Image of the area around [location], with automatic fallbacks.
class StopImage extends StatelessWidget {
  const StopImage({
    super.key,
    required this.location,
    this.size = 400,
    this.fit = BoxFit.cover,
    this.fallbackIconSize = 24,
  });

  final LatLng location;

  /// Requested image resolution in pixels (square).
  final int size;
  final BoxFit fit;
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    final satellite = _network(
      StopImageUrls.satellite(location, size: size),
      onError: _fallbackIcon(),
    );

    final streetViewUrl = StopImageUrls.streetView(location, size: size);
    if (streetViewUrl == null) return satellite;

    return _network(streetViewUrl, onError: satellite);
  }

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

  Widget _fallbackIcon() {
    return Container(
      color: AppColors.backgroundIceBlue,
      alignment: Alignment.center,
      child: Icon(
        Icons.location_on,
        size: fallbackIconSize,
        color: AppColors.secondary,
      ),
    );
  }
}

/// Map marker for a stop: a round photo thumbnail with a pointer below it.
/// Use with `Marker(width: 56, height: 68, alignment: Alignment.topCenter)`
/// so the pointer tip sits exactly on the stop's coordinates.
class StopImageMarker extends StatelessWidget {
  const StopImageMarker({super.key, required this.stop, this.onTap});

  final TransportStop stop;
  final VoidCallback? onTap;

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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.secondary, width: 3),
                boxShadow: AppShadows.card,
                color: Colors.white,
              ),
              child: ClipOval(
                child: StopImage(
                  location: stop.location,
                  size: 150,
                  fallbackIconSize: 22,
                ),
              ),
            ),
            CustomPaint(
              size: const Size(14, 10),
              painter: _PointerPainter(AppColors.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) => oldDelegate.color != color;
}

/// Bottom sheet with a large photo of the stop plus its name and landmark.
Future<void> showStopDetailsSheet(BuildContext context, TransportStop stop) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
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
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: StopImage(
                    location: stop.location,
                    size: 640,
                    fallbackIconSize: 48,
                  ),
                ),
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
