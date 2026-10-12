// lib/screens/commuter/alert.dart
//
// Alerts tab: transit announcements and service alerts for commuters.
// Shows an empty state until the alerts feed is wired in.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';

class AlertsTab extends StatelessWidget {
  const AlertsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: load commuter alerts from the backend's notifications API.
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          'Alerts',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.xs),
            border: Border.all(color: AppColors.divider),
          ),
          child: const Column(
            children: [
              Icon(AppIcons.navAlerts, size: 48, color: AppColors.brandTeal),
              SizedBox(height: AppSpacing.xs),
              Text(
                'No alerts right now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Service changes, delays and announcements for your routes will show up here.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
