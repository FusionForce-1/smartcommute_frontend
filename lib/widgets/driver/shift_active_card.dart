// lib/widgets/driver/shift_active_card.dart
//
// Shown during a shift: a live dot, the running time, when it started,
// the boarding counter and the END SHIFT button.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/driver_dashboard.dart';
import '../../utils/shift_time.dart';
import 'elapsed_clock.dart';

class ShiftActiveCard extends StatelessWidget {
  const ShiftActiveCard({
    super.key,
    required this.shift,
    required this.onPassengerChange,
    required this.onEndShift,
  });

  final DriverShift shift;
  final ValueChanged<int> onPassengerChange;
  final VoidCallback? onEndShift;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  'Shift Active',
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
              Text(
                'Started at ${formatTimeOfDay(shift.startedAt)}',
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PassengerCounter(count: shift.passengers, onChange: onPassengerChange),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: onEndShift,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              backgroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppColors.error, width: 1.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
            child: const Text('END SHIFT'),
          ),
        ],
      ),
    );
  }
}

/// Soft green dot that slowly pulses while the shift runs.
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

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

class _PassengerCounter extends StatelessWidget {
  const _PassengerCounter({required this.count, required this.onChange});

  final int count;
  final ValueChanged<int> onChange;

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
