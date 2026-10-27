// lib/widgets/driver/my_routes_card.dart
//
// The vehicles the operator assigned to this driver and their routes; for
// the one on shift, the next stop and ETA from the live broadcast.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/driver_dashboard.dart';
import '../../models/vehicle_live_update.dart';
import '../../utils/shift_time.dart';
import 'driver_card.dart';

class MyRoutesCard extends StatelessWidget {
  const MyRoutesCard({
    super.key,
    required this.vehicles,
    required this.shiftVehicleId,
    required this.live,
  });

  final List<AssignedVehicle> vehicles;
  final String? shiftVehicleId;
  final VehicleLiveUpdate? live;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      title: vehicles.length > 1 ? 'My Routes' : 'My Route',
      child: vehicles.isEmpty
          ? const Text(
              'No vehicle assigned yet — ask your operator.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final v in vehicles) _VehicleRow(vehicle: v, live: v.id == shiftVehicleId ? live : null, onShift: v.id == shiftVehicleId),
              ],
            ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({required this.vehicle, required this.live, required this.onShift});

  final AssignedVehicle vehicle;
  final VehicleLiveUpdate? live;
  final bool onShift;

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: 14, color: AppColors.textSecondary);
    const value = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.brandTeal, size: 28),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${vehicle.routeCode ?? 'Route'} · ${vehicle.plateNumber}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    Text(vehicle.routeLine, style: label),
                  ],
                ),
              ),
              if (onShift)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.shiftGreenTint,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: const Text('On shift', style: TextStyle(fontSize: 12, color: AppColors.shiftGreen)),
                ),
            ],
          ),
          if (onShift) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Text('Next stop', style: label),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(live?.nextStop ?? '—', style: value, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
            ]),
            Row(children: [
              const Text('ETA', style: label),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(formatEta(live?.etaNextStop), style: value, textAlign: TextAlign.end)),
            ]),
          ],
        ],
      ),
    );
  }
}
