// lib/widgets/commuter/vehicle_marker.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/vehicle_live_update.dart';

/// Vehicle pin: points along the heading when moving, greys out when the
/// backend reports signal_lost (last known position is kept).
class VehicleMarker extends StatelessWidget {
  const VehicleMarker({super.key, required this.vehicle, this.heading});

  final VehicleLiveUpdate vehicle;
  final double? heading; // smoothed, from VehicleTrack

  static const Color _activeColor = Color.fromARGB(255, 233, 4, 4);

  @override
  Widget build(BuildContext context) {
    final lost = vehicle.isSignalLost;
    final heading = this.heading;
    final speed = vehicle.speed;

    final Widget icon = heading != null && !lost
        ? Transform.rotate(
            angle: heading * math.pi / 180,
            child: const Icon(Icons.navigation, size: 40, color: _activeColor),
          )
        : Icon(
            lost
                ? Icons.signal_cellular_connected_no_internet_0_bar
                : Icons.directions_car,
            size: 40,
            color: lost ? Colors.grey : _activeColor,
          );

    return Tooltip(
      message: lost ? 'Signal lost — last known position' : _liveLabel(vehicle, speed),
      child: icon,
    );
  }

  /// "25 km/h  •  Next: CNU in 3 min  •  Heavy traffic"
  static String _liveLabel(VehicleLiveUpdate v, double? speed) {
    final eta = v.etaNextStop;
    final parts = [
      if (speed != null) '${speed.toStringAsFixed(0)} km/h',
      if (v.nextStop != null && eta != null && eta >= 0) 'Next: ${v.nextStop} in $eta min',
      if (v.traffic != null) '${v.traffic![0].toUpperCase()}${v.traffic!.substring(1)} traffic',
    ];
    return parts.isEmpty ? 'En route' : parts.join('  •  ');
  }
}
