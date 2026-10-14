// lib/screens/driver/shift_complete_screen.dart
//
// Shown after END SHIFT: how long the shift ran, distance, trips and
// passengers, and a summary of the route. "Start New Shift" goes back to
// the dashboard.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme_config.dart';
import '../../models/driver_dashboard.dart';
import '../../utils/shift_time.dart';
import '../../widgets/driver/elapsed_clock.dart';
import '../../widgets/driver/shift_summary_widgets.dart';

class ShiftCompleteScreen extends StatelessWidget {
  const ShiftCompleteScreen({super.key, required this.summary});

  final ShiftSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      body: Column(
        children: [
          _Header(timeRange: '${formatTimeOfDay(s.startedAt)} — ${formatTimeOfDay(s.endedAt)}'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.sm),
              children: [
                _DurationCard(duration: s.duration),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: ShiftStatTile(
                        icon: const Icon(Icons.trending_up, color: AppColors.infoBlue),
                        value: '${s.distanceKm}km',
                        label: 'Distance',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ShiftStatTile(
                        // Up-left arrow, as in the design.
                        icon: Transform.flip(
                          flipX: true,
                          child: const Icon(Icons.near_me, color: AppColors.brandTeal),
                        ),
                        value: '${s.trips}',
                        label: s.trips == 1 ? 'Trip' : 'Trips',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ShiftStatTile(
                        icon: const Icon(Icons.people_outline, color: AppColors.accent),
                        value: '${s.passengers}',
                        label: s.passengers == 1 ? 'Passenger' : 'Passengers',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ShiftSummaryTable(
                  title: s.vehicle.routeCode == null ? 'Route Summary' : 'Route ${s.vehicle.routeCode} Summary',
                  rows: [
                    ('Route', s.vehicle.routeLine),
                    ('Vehicle', s.vehicle.plateNumber),
                    ('Crowd Level', '${s.avgCrowdPercent}% avg occupancy'),
                    ('GPS Broadcasts', s.gpsCoverage.label),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const _LoggedBanner(),
              ],
            ),
          ),
          _StartNewShiftBar(onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.timeRange});

  final String timeRange;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.brandTeal,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppSpacing.md)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.md),
            child: Column(
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF4ADE80), size: 64),
                const SizedBox(height: 4),
                const Text(
                  'Shift Complete',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                Text(timeRange, style: const TextStyle(fontSize: 18, color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationCard extends StatelessWidget {
  const _DurationCard({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.brandTeal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text('Total Duration', style: TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            formatClock(duration),
            style: ElapsedClock.monoStyle.copyWith(fontSize: 38, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _LoggedBanner extends StatelessWidget {
  const _LoggedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.shiftGreenTint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.shiftGreen.withValues(alpha: 0.25), width: 1.4),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.shiftGreen, size: 30),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 14, color: AppColors.shiftGreen),
                children: [
                  TextSpan(text: 'Shift logged successfully. ', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: 'Operator has been notified.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartNewShiftBar extends StatelessWidget {
  const _StartNewShiftBar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundIceBlue,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1.4)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.shiftGreen,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            child: const Text('Start New Shift'),
          ),
        ),
      ),
    );
  }
}
