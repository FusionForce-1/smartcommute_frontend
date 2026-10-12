// lib/widgets/commuter/alert_details_sheet.dart
//
// Full text of a transit alert, opened by tapping its card.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/commuter_alert.dart';
import '../../utils/time_ago.dart';
import 'alert_style.dart';
import 'route_code_chip.dart';

Future<void> showAlertDetailsSheet(BuildContext context, CommuterAlert alert) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => SafeArea(child: AlertDetailsSheet(alert: alert)),
  );
}

class AlertDetailsSheet extends StatelessWidget {
  const AlertDetailsSheet({super.key, required this.alert});

  final CommuterAlert alert;

  @override
  Widget build(BuildContext context) {
    final style = AlertStyle.of(alert);
    final resolvedAt = alert.resolvedAt;
    final source = alert.companyName;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(style.icon, color: style.color),
              const SizedBox(width: AppSpacing.xs),
              Text(style.label, style: TextStyle(color: style.color, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(alert.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          RouteCodeChip(code: alert.routeCode ?? 'All routes'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            alert.message,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ['Posted · ${timeAgo(alert.createdAt)}', if (source != null) source].join(' · '),
            style: const TextStyle(fontSize: 13, color: AppColors.navInactive),
          ),
          if (resolvedAt != null)
            Text(
              'Resolved · ${timeAgo(resolvedAt)}',
              style: const TextStyle(fontSize: 13, color: AppColors.success),
            ),
        ],
      ),
    );
  }
}
