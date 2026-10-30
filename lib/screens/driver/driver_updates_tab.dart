// lib/screens/driver/driver_updates_tab.dart
//
// The driver's Updates tab: their notifications (shift started / ended,
// vehicle assigned or removed, announcements), filtered with the chips
// (Recent, Today, Yesterday, Last Month, Last Year) or a calendar day.
// Each filter asks the server for that period. Opening the tab marks the
// updates read.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/driver_dashboard.dart';
import '../../providers/driver_provider.dart';
import '../../utils/shift_time.dart';
import '../../utils/time_ago.dart';

class DriverUpdatesTab extends StatelessWidget {
  const DriverUpdatesTab({super.key, required this.driver});

  final DriverProvider driver;

  static const _chips = [
    UpdatesPeriod.recent,
    UpdatesPeriod.today,
    UpdatesPeriod.yesterday,
    UpdatesPeriod.lastMonth,
    UpdatesPeriod.lastYear,
  ];

  Future<void> _pickDay(BuildContext context) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: driver.updatesDay ?? today,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
      helpText: 'Show updates from',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.brandTeal),
        ),
        child: child!,
      ),
    );
    if (picked != null) driver.showUpdates(UpdatesPeriod.day, day: picked);
  }

  String get _emptyText => switch (driver.updatesPeriod) {
        UpdatesPeriod.recent => 'No updates yet.',
        UpdatesPeriod.today => 'No updates today.',
        UpdatesPeriod.yesterday => 'No updates yesterday.',
        UpdatesPeriod.lastMonth => 'No updates in the last month.',
        UpdatesPeriod.lastYear => 'No updates in the last year.',
        UpdatesPeriod.day => 'No updates on ${formatLongDate(driver.updatesDay ?? DateTime.now())}.',
      };

  @override
  Widget build(BuildContext context) {
    final updates = driver.updates;
    final day = driver.updatesDay;

    return RefreshIndicator(
      onRefresh: driver.loadUpdates,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Updates',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Date: ${formatLongDate(day ?? DateTime.now())}',
                      key: const Key('updatesDate'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              _CalendarField(day: day, onTap: () => _pickDay(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final period in _chips)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _PeriodChip(
                      label: period.label,
                      selected: driver.updatesPeriod == period,
                      onTap: () => driver.showUpdates(period),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: driver.updatesLoading && updates.isEmpty
                ? const Padding(
                    key: ValueKey('loading'),
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : updates.isEmpty
                    ? Padding(
                        key: const ValueKey('empty'),
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Text(
                          _emptyText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                        ),
                      )
                    : Column(
                        key: ValueKey('${driver.updatesPeriod}${day ?? ''}'),
                        children: [
                          for (final u in updates)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                              child: UpdateCard(update: u),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

/// "Calendar" with a "Select Date" box (the picked day once chosen).
class _CalendarField extends StatelessWidget {
  const _CalendarField({required this.day, required this.onTap});

  final DateTime? day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final day = this.day;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Calendar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: day == null ? AppColors.divider : AppColors.brandTeal, width: 1.4),
          ),
          child: InkWell(
            key: const Key('updatesCalendar'),
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day == null ? 'Select Date' : '${day.month}/${day.day}/${day.year}',
                    style: TextStyle(fontSize: 13, color: day == null ? AppColors.navInactive : AppColors.textPrimary),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? AppColors.brandTeal : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: selected ? AppColors.brandTeal : AppColors.divider, width: 1.2),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          onTap: selected ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// One update: icon, title, message and when ("5 hrs ago (October 29, 2026) 10:32 AM").
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key, required this.update});

  final DriverUpdate update;

  static IconData iconOf(String kind) => switch (kind) {
        'shift_started' => Icons.play_circle_outline,
        'shift_ended' => Icons.stop_circle_outlined,
        'vehicle_assigned' || 'vehicle_unassigned' => Icons.directions_bus_outlined,
        'transit_alert' => Icons.campaign_outlined,
        _ => Icons.notifications_none,
      };

  @override
  Widget build(BuildContext context) {
    final u = update;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: Border.all(color: AppColors.divider, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconOf(u.kind), size: 26, color: AppColors.brandTeal),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: u.isRead ? FontWeight.w600 : FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (u.body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(u.body, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                ],
                const SizedBox(height: 4),
                Text(
                  '${timeAgo(u.createdAt)} (${formatLongDate(u.createdAt)}) ${formatTimeOfDay(u.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.navInactive),
                ),
              ],
            ),
          ),
          if (!u.isRead)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 6),
              child: CircleAvatar(radius: 4, backgroundColor: AppColors.brandTeal),
            ),
        ],
      ),
    );
  }
}
