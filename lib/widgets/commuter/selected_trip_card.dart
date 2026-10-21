// lib/widgets/commuter/selected_trip_card.dart
//
// Home tab card for the route picked with "Select this route": which PUV,
// where to board and alight, fare and time. Tap it for the full details;
// the ✕ cancels the selection. While the commuter travels it also says
// where they are in the trip (services/trip_progress.dart).

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/selected_trip.dart';
import '../../models/trip_plan.dart';
import '../../services/trip_progress.dart';

class SelectedTripCard extends StatelessWidget {
  const SelectedTripCard({
    super.key,
    required this.trip,
    required this.onCancel,
    required this.onOpen,
    this.progress,
  });

  /// Where the commuter is in the trip; null before their first GPS fix.
  final TripProgressState? progress;

  final SelectedTrip trip;
  final VoidCallback onCancel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final option = trip.option;
    return Material(
      key: const Key('selectedTripCard'),
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        side: const BorderSide(color: AppColors.brandTeal, width: 1.4),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.brandTeal,
                foregroundColor: Colors.white,
                child: Icon(Icons.directions_bus),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SELECTED ROUTE',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandTeal,
                      ),
                    ),
                    Text(
                      option.routeSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trip.boardToAlight,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    if (_status() case (final icon, final text, final color)) ...[
                      const SizedBox(height: 6),
                      Row(
                        key: const Key('tripProgressStatus'),
                        children: [
                          Icon(icon, size: 18, color: color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(text,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${formatFare(option.totalFare)} · ${option.totalEtaMin} min · '
                      '${formatTransfers(option.transfers)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cancel selected route',
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _metres(double m) => m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

  /// "Walk to Central Bloc" / "On the jeep · 2.3 km to Plaza Sugbo" / …
  (IconData, String, Color)? _status() {
    final p = progress;
    if (p == null) return null;
    final leg = trip.option.legs[p.legIndex];
    return switch (p.phase) {
      TripPhase.toBoard => (Icons.directions_walk, 'Walk to ${leg.boardLabel} and board the ${leg.routeCode ?? 'jeep'}', AppColors.textPrimary),
      TripPhase.riding => (Icons.directions_bus, 'On the jeep · ${_metres(p.remainingM)} to ${leg.alightLabel}', AppColors.brandTeal),
      TripPhase.alightSoon => (Icons.notifications_active, 'Get off soon at ${leg.alightLabel}', AppColors.error),
      TripPhase.arrived => (Icons.check_circle, "You've arrived", AppColors.success),
    };
  }
}
