// lib/widgets/driver/assigned_route_card.dart
//
// The vehicle to drive (picked before the shift, locked during it), its
// route, and the next stop / ETA worked out from the live broadcast.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/driver_dashboard.dart';
import '../../models/vehicle_live_update.dart';
import '../../utils/shift_time.dart';
import 'driver_card.dart';

class AssignedRouteCard extends StatelessWidget {
  const AssignedRouteCard({
    super.key,
    required this.vehicles,
    required this.vehicle,
    required this.live,
    required this.locked,
    required this.onVehicleSelected,
  });

  final List<AssignedVehicle> vehicles;
  final AssignedVehicle? vehicle;
  final VehicleLiveUpdate? live;

  /// True during a shift: switching vehicles would mix two GPS tracks.
  final bool locked;
  final ValueChanged<String> onVehicleSelected;

  @override
  Widget build(BuildContext context) {
    final vehicle = this.vehicle;
    return DriverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.brandTeal, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assigned Route', style: DriverCard.titleStyle),
                    Text(
                      vehicle == null
                          ? 'No vehicle assigned yet — ask your operator.'
                          : '${vehicle.routeCode ?? 'Route'} — ${vehicle.routeLine}',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (vehicles.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              // Rebuilt when the selection changes from outside (e.g. a reload).
              key: ValueKey(vehicle?.id),
              initialValue: vehicle?.id,
              decoration: InputDecoration(
                labelText: 'Vehicle',
                helperText: locked ? 'End your shift to switch vehicles.' : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: [
                for (final v in vehicles)
                  DropdownMenuItem(value: v.id, child: Text(v.plateNumber)),
              ],
              onChanged: locked ? null : (id) => id == null ? null : onVehicleSelected(id),
            ),
          ],
          const SizedBox(height: 12),
          _InfoRow(label: 'Vehicle', value: vehicle?.plateNumber ?? '—'),
          _InfoRow(label: 'Next stop', value: live?.nextStop ?? '—'),
          _InfoRow(label: 'ETA', value: formatEta(live?.etaNextStop)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
