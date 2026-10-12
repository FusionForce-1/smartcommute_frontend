// lib/widgets/commuter/alert_card.dart
//
// One alert on the Notifications screen. Unread alerts are tinted in
// their colour with a dot before the title; read ones turn white.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/commuter_alert.dart';
import '../../utils/time_ago.dart';
import 'alert_style.dart';
import 'route_code_chip.dart';

class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.alert,
    required this.onTap,
    this.showUnread = true,
  });

  final CommuterAlert alert;
  final VoidCallback onTap;

  /// False for guests, who have no read state.
  final bool showUnread;

  @override
  Widget build(BuildContext context) {
    final style = AlertStyle.of(alert);
    final unread = showUnread && !alert.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: unread ? style.background : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          side: BorderSide(color: unread ? style.color : AppColors.divider, width: 1.4),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 8, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AlertIcon(style: style),
                const SizedBox(width: 12),
                Expanded(child: _AlertBody(alert: alert, style: style, unread: unread)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertIcon extends StatelessWidget {
  const _AlertIcon({required this.style});

  final AlertStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: style.color, width: 1.4),
      ),
      child: Icon(style.icon, color: style.color, size: 26),
    );
  }
}

class _AlertBody extends StatelessWidget {
  const _AlertBody({required this.alert, required this.style, required this.unread});

  final CommuterAlert alert;
  final AlertStyle style;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (unread) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                alert.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.schedule, size: 14, color: AppColors.navInactive),
            const SizedBox(width: 3),
            Text(
              timeAgo(alert.createdAt),
              style: const TextStyle(fontSize: 11, color: AppColors.navInactive),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.navInactive),
          ],
        ),
        const SizedBox(height: 6),
        RouteCodeChip(code: alert.routeCode ?? 'All routes', compact: true),
        const SizedBox(height: AppSpacing.xs),
        Text(
          alert.message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.3),
        ),
      ],
    );
  }
}
