// Shift card
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/driver_dashboard.dart';
import '../../providers/driver_provider.dart';
import '../../utils/shift_time.dart';
import 'driver_card.dart';
import 'elapsed_clock.dart';

/// Shift card
class ShiftCard extends StatelessWidget {
  /// Create shift card
  const ShiftCard({
    super.key,
    required this.shift,
    required this.vehicle,
    required this.jeepGps,
    required this.gpsError,
    required this.onRetryGps,
    required this.onPassengerChange,
  });

  final DriverShift? shift;
  final AssignedVehicle? vehicle;
  final JeepGps jeepGps;

  final String? gpsError;
  final VoidCallback onRetryGps;
  final ValueChanged<int> onPassengerChange;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final shift = this.shift;
    if (shift == null) {
      return const DriverCard(
        key: Key('offShift'),
        child: Row(
          children: [
            Icon(Icons.event_busy_outlined, size: 30, color: AppColors.navInactive),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Not on shift', style: DriverCard.titleStyle),
                  Text(
                    'Your operator starts and ends your shift. It shows here as soon as it starts.',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    const detail = TextStyle(fontSize: 15, color: AppColors.textSecondary);
    return Container(
      key: const Key('onShift'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.shiftGreenTint,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.shiftGreen, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _LiveDot(),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'On Shift',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.shiftGreen),
                ),
              ),
              ElapsedClock(since: shift.startedAt, style: const TextStyle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, size: 22, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Started at ${formatTimeOfDay(shift.startedAt)}'
                  '${vehicle == null ? '' : ' · ${vehicle!.plateNumber}'}',
                  style: detail,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.trending_up, size: 22, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text('Distance: ${shift.distanceKm.toStringAsFixed(1)} km', style: detail),
            ],
          ),
          const SizedBox(height: 12),
          _GpsLine(jeepGps: jeepGps, gpsError: gpsError, onRetry: onRetryGps),
          const SizedBox(height: 12),
          _PassengerCounter(count: shift.passengers, onChange: onPassengerChange),
        ],
      ),
    );
  }
}

/// GPS line widget
class _GpsLine extends StatelessWidget {
  /// Create GPS line
  const _GpsLine({required this.jeepGps, required this.gpsError, required this.onRetry});

  final JeepGps jeepGps;
  final String? gpsError;
  final VoidCallback onRetry;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = switch (jeepGps) {
      JeepGps.tracker => (Icons.gps_fixed, AppColors.shiftGreen, "GPS from the jeep's tracker"),
      JeepGps.phone => (Icons.smartphone, AppColors.accent, 'Tracker offline — sharing your phone\'s location'),
      JeepGps.none => (Icons.gps_off, AppColors.error, 'No GPS from the jeep right now'),
    };
    final error = gpsError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          key: const Key('jeepGps'),
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(text, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w600))),
          ],
        ),
        if (error == DriverProvider.noTrackerMessage)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(DriverProvider.noTrackerMessage, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          )
        else if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Your phone can't back up the tracker: $error",
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('Try again')),
              ],
            ),
          ),
      ],
    );
  }
}

/// Live dot widget
class _LiveDot extends StatefulWidget {
  /// Create live dot
  const _LiveDot();

  /// Create widget state
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

/// Live dot state
class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  /// Clean up resources
  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_pulse),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [AppColors.shiftGreen, AppColors.shiftGreen.withValues(alpha: 0.15)],
          ),
        ),
      ),
    );
  }
}

/// Passenger counter widget
class _PassengerCounter extends StatelessWidget {
  /// Create passenger counter
  const _PassengerCounter({required this.count, required this.onChange});

  final int count;
  final ValueChanged<int> onChange;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.people_outline, size: 22, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'Passengers: $count',
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
          ),
        ),
        IconButton(
          tooltip: 'Undo last passenger',
          onPressed: count > 0 ? () => onChange(-1) : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: AppColors.textSecondary,
        ),
        FilledButton.icon(
          onPressed: () => onChange(1),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('1 Passenger'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.shiftGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
