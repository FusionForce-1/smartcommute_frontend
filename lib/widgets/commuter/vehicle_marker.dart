// lib/widgets/commuter/vehicle_marker.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/vehicle_live_update.dart';

/// The PUV, seen from above (front at the top). Once it moves it turns to
/// face its heading, so the vehicle itself shows the direction of travel.
/// Greys out when the backend reports signal_lost (last known position kept)
/// or the jeep isn't in service (no shift started, or driver set Unavailable).
class VehicleMarker extends StatelessWidget {
  const VehicleMarker({super.key, required this.vehicle, this.heading});

  final VehicleLiveUpdate vehicle;
  final double? heading; // smoothed, from VehicleTrack; null until it has moved

  static const String asset = 'assets/icons/puv.svg';

  @override
  Widget build(BuildContext context) {
    final lost = vehicle.isSignalLost;
    final offDuty = !lost && vehicle.isUnavailable;   // no shift, or the driver set Unavailable
    final heading = this.heading;

    Widget icon = SvgPicture.asset(asset, key: const ValueKey('puvIcon'), fit: BoxFit.contain);
    if (heading != null) {
      icon = Transform.rotate(angle: heading * math.pi / 180, child: icon);
    }
    if (lost || offDuty) {
      icon = Opacity(
        opacity: lost ? 0.55 : 0.7,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.33, 0.33, 0.33, 0, 0, //
            0.33, 0.33, 0.33, 0, 0, //
            0.33, 0.33, 0.33, 0, 0, //
            0, 0, 0, 1, 0,
          ]),
          child: icon,
        ),
      );
    }

    return Tooltip(
      message: lost
          ? 'Signal lost — last known position'
          : offDuty
              ? 'Not in service — not taking passengers right now'
              : _liveLabel(vehicle, vehicle.speed),
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
