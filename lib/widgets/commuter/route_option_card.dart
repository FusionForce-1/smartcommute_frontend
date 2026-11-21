// Route option card
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/transport_model.dart';
import '../../models/trip_plan.dart';
import 'route_code_chip.dart';

/// Route option card
class RouteOptionCard extends StatelessWidget {
  /// Create route option card
  const RouteOptionCard({
    super.key,
    required this.option,
    required this.routesById,
    required this.selected,
    required this.onTap,
  });

  final RouteOption option;

  final Map<String, TransportRoute> routesById;
  final bool selected;
  final VoidCallback onTap;

  String get _details {
    final stops = option.stopCount(routesById);
    final transfers = formatTransfers(option.transfers);
    return stops == null ? transfers : '$stops ${stops == 1 ? 'stop' : 'stops'}  •  $transfers';
  }

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: selected ? AppColors.backgroundIceBlue : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          side: BorderSide(
            color: selected ? AppColors.secondary : AppColors.divider,
            width: selected ? 1.6 : 1.4,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selected) ...[
                  const _SelectedBadge(),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Row(
                  children: [
                    Expanded(child: _LegCodes(option: option, routesById: routesById)),
                    _FareBadge(fare: option.totalFare),
                  ],
                ),
                if (option.totalFareDiscounted case final discounted?)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Student/Senior/PWD ${formatFareCompact(discounted)}',
                      key: const Key('discountedFare'),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.legs.map((leg) => leg.routeName).join(' → '),
                        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '~${option.totalEtaMin} min',
                          style: const TextStyle(fontSize: 17, color: AppColors.textPrimary),
                        ),
                        if (option.arriveAt != null)
                          Text(
                            'Arrive ${TimeOfDay.fromDateTime(option.arriveAt!.toLocal()).format(context)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(_details, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                if (trafficSummary(option) case final traffic?)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.traffic, size: 16, color: _trafficColor(option)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(traffic,
                              style: TextStyle(fontSize: 13, color: _trafficColor(option))),
                        ),
                      ],
                    ),
                  ),
                for (final leg in option.legs)
                  if (boardingSummary(leg) case final summary?)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            leg.waitIsLive ? Icons.directions_bus : Icons.directions_walk,
                            size: 16,
                            color: leg.waitIsLive ? AppColors.success : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              option.legs.length > 1 ? '${leg.routeCode ?? leg.routeName}: $summary' : summary,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Traffic color
Color _trafficColor(RouteOption option) {
  final levels = option.legs.map((l) => l.traffic);
  if (levels.contains('heavy')) return AppColors.error;
  if (levels.contains('moderate')) return AppColors.accent;
  return AppColors.success;
}

/// Leg codes widget
class _LegCodes extends StatelessWidget {
  /// Create leg codes
  const _LegCodes({required this.option, required this.routesById});

  final RouteOption option;
  final Map<String, TransportRoute> routesById;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final codes = [
      for (final leg in option.legs) routesById[leg.routeId]?.code ?? leg.routeName,
    ];

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < codes.length; i++) ...[
          if (i > 0) const Text('→', style: TextStyle(fontSize: 16)),
          RouteCodeChip(code: codes[i]),
        ],
      ],
    );
  }
}

/// Selected badge
class _SelectedBadge extends StatelessWidget {
  /// Create selected badge
  const _SelectedBadge();

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandTeal,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: const Text('Selected', style: TextStyle(fontSize: 13, color: Colors.white)),
    );
  }
}

/// fare badge
class _FareBadge extends StatelessWidget {
  /// Create fare badge
  const _FareBadge({required this.fare});

  final double fare;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        formatFareCompact(fare),
        style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
      ),
    );
  }
}
