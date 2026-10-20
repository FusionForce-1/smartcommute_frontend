// lib/screens/commuter/route_map_screen.dart
//
// "View Selected Route on Map": draws each leg's route line with its
// board / alight stops, framed to fit, above the fare breakdown.
// With [onSelect], a "Select this route" button below sends the route to
// the Home map (the dashboard shows it there until it's cancelled).

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../config/map_config.dart';
import '../../config/theme_config.dart';
import '../../models/transport_model.dart';
import '../../models/trip_plan.dart';
import '../../widgets/commuter/commuter_page_header.dart';
import '../../widgets/commuter/trip_route_layers.dart';
import '../../widgets/fare_breakdown_sheet.dart';

class RouteMapScreen extends StatelessWidget {
  const RouteMapScreen({
    super.key,
    required this.option,
    required this.routesById,
    this.onSelect,
  });

  final RouteOption option;
  final Map<String, TransportRoute> routesById;

  /// "Select this route"; null hides the button (e.g. opened from Home,
  /// where this route is already the selected one).
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final layers = TripRouteLayers.of(option, routesById);
    final points = layers.points;

    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      body: Column(
        children: [
          const CommuterPageHeader(title: 'Selected Route'),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: points.isEmpty ? MapConfig.defaultCenter : points.first,
                initialZoom: 14,
                initialCameraFit: layers.cameraFit,
                minZoom: MapConfig.minZoom,
                maxZoom: MapConfig.maxZoom,
                cameraConstraint: CameraConstraint.contain(bounds: MapConfig.mapBounds),
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConfig.tileUrl,
                  userAgentPackageName: MapConfig.userAgentPackageName,
                ),
                PolylineLayer(polylines: layers.lines),
                MarkerLayer(markers: layers.markers),
              ],
            ),
          ),
          _FarePanel(option: option, onSelect: onSelect),
        ],
      ),
    );
  }
}

/// Fare breakdown under the map (scrollable on short screens), with the
/// "Select this route" button pinned below it.
class _FarePanel extends StatelessWidget {
  const _FarePanel({required this.option, this.onSelect});

  final RouteOption option;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final onSelect = this.onSelect;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: FareBreakdownSheet(option: option),
              ),
            ),
            if (onSelect != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
                child: FilledButton.icon(
                  key: const Key('selectThisRoute'),
                  onPressed: onSelect,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandTeal,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Select this route'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
