// lib/screens/commuter/pick_destination_screen.dart
//
// I-drag ang map para ang pin sa tunga mao ang destination.
// Mo-pop og LatLng kung i-tap ang "Set destination".

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/map_config.dart';
import '../../config/theme_config.dart';

/// Sugod sa location sa commuter kung naa sa service area,
/// kung dili, sa default center (para dili ma-assert ang camera constraint).
LatLng initialPickCenter(LatLng? origin) {
  if (origin != null && MapConfig.serviceArea.contains(origin)) return origin;
  return MapConfig.defaultCenter;
}

class PickDestinationScreen extends StatefulWidget {
  const PickDestinationScreen({super.key, this.origin});

  final LatLng? origin;

  @override
  State<PickDestinationScreen> createState() => _PickDestinationScreenState();
}

class _PickDestinationScreenState extends State<PickDestinationScreen> {
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Pick destination'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialPickCenter(widget.origin),
              initialZoom: 15,
              minZoom: MapConfig.minZoom,
              maxZoom: MapConfig.maxZoom,
              cameraConstraint: CameraConstraint.contain(
                bounds: MapConfig.serviceArea,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrl,
                userAgentPackageName: MapConfig.userAgentPackageName,
              ),
            ],
          ),
          // Tip sa pin mao ang center sa map (icon gi-offset og tunga sa iyang height)
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 48),
                child: Icon(Icons.location_pin, size: 48, color: AppColors.error),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: SafeArea(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () =>
                    Navigator.of(context).pop(_mapController.camera.center),
                icon: const Icon(Icons.check),
                label: const Text('Set destination'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
