// lib/widgets/driver/shift_summary_widgets.dart
//
// Pieces of the Shift Complete screen: a stat tile (Distance / Trips /
// Passengers) and the route summary table.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';

class ShiftStatTile extends StatelessWidget {
  const ShiftStatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  /// Shown at 34 px, e.g. Icon(Icons.trending_up, color: ...).
  final Widget icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider, width: 1.4),
      ),
      child: Column(
        children: [
          IconTheme.merge(data: const IconThemeData(size: 34), child: icon),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class ShiftSummaryTable extends StatelessWidget {
  const ShiftSummaryTable({super.key, required this.title, required this.rows});

  final String title;

  /// (label, value) pairs.
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.divider, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          for (final (label, value) in rows) ...[
            const Divider(height: 1, thickness: 1.4, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
