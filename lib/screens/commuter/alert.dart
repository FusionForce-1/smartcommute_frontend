// lib/screens/commuter/alert.dart
//
// Alerts tab — "Notifications": transit alerts with unread count, Mark all
// read and filters. Tapping an alert marks it read and opens its details.
// Pull down to refresh. State lives in AlertsProvider (owned by the dashboard).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../models/commuter_alert.dart';
import '../../providers/alerts_provider.dart';
import '../../providers/load_state.dart';
import '../../widgets/commuter/alert_card.dart';
import '../../widgets/commuter/alert_details_sheet.dart';
import '../../widgets/commuter/alert_filter_bar.dart';

class AlertsTab extends StatelessWidget {
  const AlertsTab({super.key});

  void _open(BuildContext context, CommuterAlert alert) {
    context.read<AlertsProvider>().markRead(alert);
    showAlertDetailsSheet(context, alert);
  }

  Future<void> _markAllRead(BuildContext context) async {
    final error = await context.read<AlertsProvider>().markAllRead();
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<AlertsProvider>();

    return RefreshIndicator(
      onRefresh: alerts.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const Text(
            'Notifications',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (alerts.tracksReadState)
            Row(
              children: [
                Text(
                  '${alerts.unreadCount} unread',
                  style: const TextStyle(fontSize: 17, color: AppColors.textPrimary),
                ),
                const Spacer(),
                TextButton(
                  onPressed: alerts.unreadCount == 0 ? null : () => _markAllRead(context),
                  style: TextButton.styleFrom(foregroundColor: AppColors.brandTeal),
                  child: const Text('Mark all read', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.xs),
          AlertFilterBar(selected: alerts.filter, onSelected: alerts.setFilter),
          const SizedBox(height: AppSpacing.md),
          ..._content(context, alerts),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, AlertsProvider alerts) {
    switch (alerts.state) {
      case LoadState.idle:
      case LoadState.loading:
        return const [
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      case LoadState.error:
        return [
          _Message(
            icon: AppIcons.errorRetry,
            text: alerts.errorMessage ?? "Couldn't load alerts.",
            color: AppColors.error,
            onRetry: alerts.load,
          ),
        ];
      case LoadState.ready:
        final visible = alerts.visibleAlerts;
        if (visible.isEmpty) {
          return [
            _Message(
              icon: AppIcons.navAlerts,
              text: alerts.filter == AlertFilter.all
                  ? 'No alerts right now. Service updates for your routes will show up here.'
                  : 'No ${alerts.filter.label.toLowerCase()} alerts right now.',
            ),
          ];
        }
        return [
          for (final alert in visible)
            AlertCard(
              alert: alert,
              showUnread: alerts.tracksReadState,
              onTap: () => _open(context, alert),
            ),
        ];
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.color = AppColors.textSecondary,
    this.onRetry,
  });

  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final onRetry = this.onRetry;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Icon(icon, size: 44, color: color),
          const SizedBox(height: AppSpacing.xs),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 15)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
