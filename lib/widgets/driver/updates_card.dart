// lib/widgets/driver/updates_card.dart
//
// The driver's latest updates: shift started / ended by the operator, a
// vehicle assigned, announcements. Unread ones are bold with a dot.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/driver_dashboard.dart';
import '../../utils/time_ago.dart';
import 'driver_card.dart';

class UpdatesCard extends StatelessWidget {
  const UpdatesCard({super.key, required this.updates, required this.onMarkAllRead});

  final List<DriverUpdate> updates;
  final VoidCallback onMarkAllRead;

  static const int shown = 10;

  static IconData _icon(String kind) => switch (kind) {
        'shift_started' => Icons.play_circle_outline,
        'shift_ended' => Icons.stop_circle_outlined,
        'vehicle_assigned' || 'vehicle_unassigned' => Icons.directions_bus_outlined,
        'transit_alert' => Icons.campaign_outlined,
        _ => Icons.notifications_none,
      };

  @override
  Widget build(BuildContext context) {
    final anyUnread = updates.any((u) => !u.isRead);
    return DriverCard(
      title: 'Updates',
      trailing: anyUnread ? TextButton(onPressed: onMarkAllRead, child: const Text('Mark all read')) : null,
      child: updates.isEmpty
          ? const Text('No updates yet.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary))
          : Column(
              children: [
                for (final u in updates.take(shown))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(_icon(u.kind), size: 22, color: AppColors.brandTeal),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: u.isRead ? FontWeight.w500 : FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (u.body.isNotEmpty)
                                Text(u.body, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              Text(timeAgo(u.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.navInactive)),
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
                  ),
              ],
            ),
    );
  }
}
