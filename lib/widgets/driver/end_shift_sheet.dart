// lib/widgets/driver/end_shift_sheet.dart
//
// "End Shift?" confirmation. Resolves to true when the driver confirms.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../utils/shift_time.dart';
import 'elapsed_clock.dart';

Future<bool> showEndShiftSheet(BuildContext context, {required DateTime startedAt}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.md)),
    ),
    builder: (_) => _EndShiftSheet(startedAt: startedAt),
  );
  return confirmed ?? false;
}

class _EndShiftSheet extends StatelessWidget {
  const _EndShiftSheet({required this.startedAt});

  final DateTime startedAt;

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: 16, color: AppColors.textSecondary);
    const value = TextStyle(fontSize: 16, color: AppColors.textPrimary);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.errorBackground,
                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 30),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('End Shift?',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      SizedBox(height: 4),
                      Text('This will stop GPS broadcast and mark as unavailable', style: label),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.panelGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Shift duration', style: label)),
                      ElapsedClock(since: startedAt, style: value),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Text('Start at', style: label)),
                      Text(formatTimeOfDay(startedAt), style: value),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      minimumSize: const Size.fromHeight(54),
                      side: const BorderSide(color: AppColors.divider, width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 18),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandTeal,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('End Shift'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
