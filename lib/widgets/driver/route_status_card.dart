// lib/widgets/driver/route_status_card.dart
//
// On-Route / Delayed / Unavailable: what commuters are told about this trip.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/driver_dashboard.dart';
import 'driver_card.dart';

class RouteStatusCard extends StatelessWidget {
  const RouteStatusCard({super.key, required this.selected, required this.onSelected});

  final DutyStatus selected;
  final ValueChanged<DutyStatus> onSelected;

  static Color colorOf(DutyStatus status) => switch (status) {
        DutyStatus.onRoute => AppColors.shiftGreen,
        DutyStatus.delayed => AppColors.accent,
        DutyStatus.unavailable => AppColors.navInactive,
      };

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      title: 'Route Status',
      child: Row(
        children: [
          for (final status in DutyStatus.values) ...[
            if (status != DutyStatus.values.first) const SizedBox(width: 12),
            Expanded(
              child: _StatusButton(
                label: status.label,
                color: colorOf(status),
                selected: status == selected,
                onTap: () => onSelected(status),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: selected ? color : AppColors.divider, width: 1.4),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? color : Colors.white,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: SizedBox(
            height: 44,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 15, color: selected ? Colors.white : AppColors.textPrimary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
