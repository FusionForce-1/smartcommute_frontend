// Selected trip card
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/selected_trip.dart';
import '../../models/trip_plan.dart';
import '../../services/trip_eta.dart';
import '../../services/trip_progress.dart';

/// Selected trip card
class SelectedTripCard extends StatelessWidget {
  /// Create selected trip card
  const SelectedTripCard({
    super.key,
    required this.trip,
    required this.onCancel,
    required this.onOpen,
    this.progress,
    this.eta,
    this.boardedPlate,
  });

  final TripProgressState? progress;

  final TripEta? eta;

  final String? boardedPlate;

  final SelectedTrip trip;
  final VoidCallback onCancel;
  final VoidCallback onOpen;

  /// Build the widget
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
                    if (_onBoard() case final banner?) ...[
                      const SizedBox(height: 6),
                      banner,
                    ],
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
                    if (_waitLine() case final wait?) ...[
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: Text(
                          wait,
                          key: const Key('tripWaitLine'),
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${formatFare(option.totalFare)} · ${_time(context)} · '
                      '${formatTransfers(option.transfers)}',
                      key: const Key('tripSummaryLine'),
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

  /// Selected trip metres
  static String _metres(double m) => m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

  /// Selected trip name
  static String _name(RouteLeg leg) => leg.routeCode ?? leg.routeName;

  /// Selected trip time
  String _time(BuildContext context) {
    final e = eta;
    if (e == null) return '${trip.option.totalEtaMin} min';
    return 'Arrive ${TimeOfDay.fromDateTime(e.arriveAt.toLocal()).format(context)} · ${e.minutes} min';
  }

  /// On board
  Widget? _onBoard() {
    final p = progress;
    final plate = boardedPlate;
    if (p == null || plate == null || !p.isRiding) return null;
    final leg = trip.option.legs[p.legIndex];
    return Container(
      key: const Key('onBoardBanner'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, size: 18, color: AppColors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: "You're on the ${_name(leg)} you were waiting for"),
                if (plate.isNotEmpty) TextSpan(text: ' · $plate', style: const TextStyle(fontWeight: FontWeight.w400)),
              ]),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String, Color)? _status() {
    final p = progress;
    if (p == null) return null;
    final leg = trip.option.legs[p.legIndex];
    final e = eta;
    final rideLeft = e?.rideLeftMin == null ? '' : ' · about ${e!.rideLeftMin} min';
    return switch (p.phase) {
      TripPhase.toBoard when e != null && e.atStop =>
        (Icons.hourglass_top, 'At ${leg.boardLabel} · wait for the ${_name(leg)}', AppColors.textPrimary),
      TripPhase.toBoard when e?.walkMin != null =>
        (Icons.directions_walk, 'Walk ${e!.walkMin} min to ${leg.boardLabel}, then board the ${_name(leg)}', AppColors.textPrimary),
      TripPhase.toBoard => (Icons.directions_walk, 'Walk to ${leg.boardLabel} and board the ${leg.routeCode ?? 'jeep'}', AppColors.textPrimary),
      TripPhase.riding => (Icons.directions_bus, 'On the jeep · ${_metres(p.remainingM)} to ${leg.alightLabel}$rideLeft', AppColors.brandTeal),
      TripPhase.alightSoon => (Icons.notifications_active, 'Get off soon at ${leg.alightLabel}', AppColors.error),
      TripPhase.arrived => (Icons.check_circle, "You've arrived", AppColors.success),
    };
  }

  /// Wait line
  String? _waitLine() {
    final p = progress;
    final e = eta;
    if (p == null || e == null || p.phase != TripPhase.toBoard) return null;
    final name = _name(trip.option.legs[p.legIndex]);
    if (!e.waitIsLive) return 'No live $name yet · usual wait about ${e.waitMin} min';
    if (e.jeepInMin == 0) return 'A $name is at the stop now';
    return 'Next $name reaches the stop in ${e.jeepInMin} min';
  }
}
