// lib/widgets/driver/report_sheet.dart
//
// "Report to operator": pick what happened, add a note (needed for Other),
// Send. One request id per opened sheet, so trying again after a dropped
// connection never sends the report twice. The sheet stays open, with the
// note kept, when sending fails; on success it closes with a confirmation.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/driver_report.dart';
import '../../providers/driver_provider.dart';
import '../../utils/request_id.dart';

/// Opens the sheet; returns the confirmation to show, or null if closed without sending.
Future<String?> showReportSheet(BuildContext context, DriverProvider driver) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: SafeArea(child: ReportSheet(driver: driver)),
    ),
  );
}

/// Colour and icon for each kind of report.
class ReportCategoryStyle {
  const ReportCategoryStyle._(this.color, this.icon);

  final Color color;
  final IconData icon;

  static ReportCategoryStyle of(DriverReportCategory category) => switch (category) {
        DriverReportCategory.emergency => const ReportCategoryStyle._(AppColors.error, Icons.sos_outlined),
        DriverReportCategory.breakdown => const ReportCategoryStyle._(AppColors.accent, Icons.car_crash_outlined),
        DriverReportCategory.delay => const ReportCategoryStyle._(AppColors.accent, Icons.traffic_outlined),
        DriverReportCategory.vehicleIssue => const ReportCategoryStyle._(AppColors.brandTeal, Icons.build_outlined),
        DriverReportCategory.other => const ReportCategoryStyle._(AppColors.brandTeal, Icons.chat_bubble_outline),
      };
}

class ReportSheet extends StatefulWidget {
  const ReportSheet({super.key, required this.driver});

  final DriverProvider driver;

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final String _requestId = newRequestId();
  final TextEditingController _note = TextEditingController();
  DriverReportCategory? _category;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _canSend {
    final category = _category;
    if (category == null || _sending) return false;
    return !category.needsNote || _note.text.trim().isNotEmpty;
  }

  Future<void> _send() async {
    final category = _category;
    if (category == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await widget.driver.sendReport(category, note: _note.text, requestId: _requestId);
    if (!mounted) return;
    final sent = result.sent;
    if (sent == null) {
      setState(() {
        _sending = false;
        _error = result.error;
      });
      return;
    }
    final shift = sent.context;
    Navigator.of(context).pop(switch (shift) {
      null => 'Sent to your operator.',
      _ when shift.hasLocation => 'Sent to your operator with ${shift.plateNumber} and your location.',
      _ => 'Sent to your operator with ${shift.plateNumber}.',
    });
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    final error = _error;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report to operator', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'Only your operator sees this. While you are on shift, your jeep and location are added for you.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final c in DriverReportCategory.values)
                ChoiceChip(
                  key: Key('reportCategory_${c.apiValue}'),
                  avatar: Icon(
                    ReportCategoryStyle.of(c).icon,
                    size: 18,
                    color: c == category ? Colors.white : ReportCategoryStyle.of(c).color,
                  ),
                  label: Text(c.label),
                  selected: c == category,
                  showCheckmark: false,
                  selectedColor: ReportCategoryStyle.of(c).color,
                  labelStyle: TextStyle(color: c == category ? Colors.white : AppColors.textPrimary),
                  onSelected: _sending ? null : (_) => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('reportNote'),
            controller: _note,
            enabled: !_sending,
            maxLength: reportNoteMaxLength,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: category?.needsNote == true ? 'What happened? (required)' : 'Add a note (optional)',
              border: const OutlineInputBorder(),
            ),
          ),
          if (error != null) ...[
            Text(error, key: const Key('reportError'), style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: AppSpacing.xs),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('sendReport'),
              onPressed: _canSend ? _send : null,
              style: FilledButton.styleFrom(
                backgroundColor: category == DriverReportCategory.emergency ? AppColors.error : AppColors.brandTeal,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(error == null ? 'Send' : 'Try again'),
            ),
          ),
        ],
      ),
    );
  }
}
