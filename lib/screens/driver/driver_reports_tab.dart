// lib/screens/driver/driver_reports_tab.dart
//
// The driver's Reports tab: "Report to operator" (a breakdown, a delay, an
// emergency, ...) and the reports they've sent, filtered with the chips
// (Recent, Today, Yesterday, Last Month, Last Year) or a calendar day.
// Reports only go to the driver's own operator, and operators can't reply
// here, so there is no read state to show.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/driver_report.dart';
import '../../providers/driver_provider.dart';
import '../../utils/shift_time.dart';
import '../../utils/time_ago.dart';
import '../../widgets/driver/report_sheet.dart';

class DriverReportsTab extends StatelessWidget {
  const DriverReportsTab({super.key, required this.driver});

  final DriverProvider driver;

  static const _chips = [
    ReportsPeriod.recent,
    ReportsPeriod.today,
    ReportsPeriod.yesterday,
    ReportsPeriod.lastMonth,
    ReportsPeriod.lastYear,
  ];

  Future<void> _pickDay(BuildContext context) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: driver.reportsDay ?? today,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
      helpText: 'Show reports from',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.brandTeal),
        ),
        child: child!,
      ),
    );
    if (picked != null) driver.showReports(ReportsPeriod.day, day: picked);
  }

  Future<void> _report(BuildContext context) async {
    final confirmation = await showReportSheet(context, driver);
    if (confirmation != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(confirmation)));
    }
  }

  String get _emptyText => switch (driver.reportsPeriod) {
        ReportsPeriod.recent => 'No reports sent yet.',
        ReportsPeriod.today => 'No reports sent today.',
        ReportsPeriod.yesterday => 'No reports sent yesterday.',
        ReportsPeriod.lastMonth => 'No reports sent in the last month.',
        ReportsPeriod.lastYear => 'No reports sent in the last year.',
        ReportsPeriod.day => 'No reports sent on ${formatLongDate(driver.reportsDay ?? DateTime.now())}.',
      };

  @override
  Widget build(BuildContext context) {
    final reports = driver.reports;
    final day = driver.reportsDay;

    return RefreshIndicator(
      onRefresh: driver.loadReports,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
        children: [
          const Text(
            'Reports',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tell your operator about a breakdown, a delay or an emergency.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('reportToOperator'),
              onPressed: () => _report(context),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Report to operator'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandTeal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sent reports',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Date: ${formatLongDate(day ?? DateTime.now())}',
                      key: const Key('reportsDate'),
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
                      selected: driver.reportsPeriod == period,
                      onTap: () => driver.showReports(period),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: driver.reportsLoading && reports.isEmpty
                ? const Padding(
                    key: ValueKey('loading'),
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : reports.isEmpty
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
                        key: ValueKey('${driver.reportsPeriod}${day ?? ''}'),
                        children: [
                          for (final r in reports)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                              child: ReportCard(report: r),
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
            key: const Key('reportsCalendar'),
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

/// One sent report: category, note, the vehicle it was sent from, and when
/// ("5 hrs ago (October 29, 2026) 10:32 AM").
class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report});

  final DriverReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final style = ReportCategoryStyle.of(r.category);
    final shiftInfo = r.context;
    final note = r.note;
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
          Icon(style.icon, size: 26, color: style.color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.category.label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                ],
                if (shiftInfo != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      shiftInfo.plateNumber,
                      if (shiftInfo.routeCode != null) shiftInfo.routeCode!,
                      if (shiftInfo.hasLocation) 'location shared',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${timeAgo(r.createdAt)} (${formatLongDate(r.createdAt)}) ${formatTimeOfDay(r.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.navInactive),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
