// lib/widgets/driver/driver_profile_card.dart
//
// Avatar, name, route code and plate number at the top of the dashboard.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/driver_dashboard.dart';
import 'driver_card.dart';

class DriverProfileCard extends StatelessWidget {
  const DriverProfileCard({super.key, required this.name, required this.vehicle});

  final String name;
  final AssignedVehicle? vehicle;

  @override
  Widget build(BuildContext context) {
    const detail = TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4);
    return DriverCard(
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.divider,
            child: Icon(Icons.person_outline, size: 34, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: DriverCard.titleStyle),
                Text('Route: ${vehicle?.routeCode ?? '—'}', style: detail),
                Text('Vehicle: ${vehicle?.plateNumber ?? 'Not assigned'}', style: detail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
