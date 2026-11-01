// lib/widgets/driver/route_status_card.dart
//
// "Route Status": On-Route / Delayed / Unavailable. The chosen one is
// filled; commuters see it on the live map. Only changeable during a shift.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/driver_dashboard.dart';
import 'driver_card.dart';

class RouteStatusCard extends StatelessWidget {
  const RouteStatusCard({super.key, required this.status, required this.onChanged});

  final RouteStatus status;

  /// Null while off shift: the buttons are shown but locked.
  final ValueChanged<RouteStatus>? onChanged;

  static Color colorOf(RouteStatus status) => switch (status) {
        RouteStatus.onRoute => AppColors.shiftGreen,
        RouteStatus.delayed => AppColors.accent,
        RouteStatus.unavailable => AppColors.navInactive,
      };

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return DriverCard(
      key: const Key('routeStatusCard'),
      title: 'Route Status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final s in RouteStatus.values) ...[
                if (s != RouteStatus.values.first) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _StatusButton(
                    status: s,
                    selected: s == status,
                    onPressed: onChanged == null ? null : () => onChanged(s),
                  ),
                ),
              ],
            ],
          ),
          if (onChanged == null)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'You can change this once your shift starts.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.status, required this.selected, required this.onPressed});

  final RouteStatus status;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = RouteStatusCard.colorOf(status);
    final enabled = onPressed != null;
    return AnimatedContainer(
      key: Key('routeStatus_${status.apiValue}'),
      duration: const Duration(milliseconds: 200),
      height: 40,
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: enabled ? 1 : 0.45) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? Colors.transparent : AppColors.divider, width: 1.4),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: selected ? null : onPressed,
          child: Center(
            child: Semantics(
              selected: selected,
              button: true,
              child: Text(
                status.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? Colors.white
                      : (enabled ? AppColors.textPrimary : AppColors.navInactive),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
