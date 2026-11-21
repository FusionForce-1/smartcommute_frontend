// Traffic report card
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import 'driver_card.dart';

/// Traffic report card
class TrafficReportCard extends StatelessWidget {
  /// Create traffic report card
  const TrafficReportCard({super.key, required this.reported, required this.onReport});

  final bool? reported;

  final ValueChanged<bool>? onReport;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final onReport = this.onReport;
    return DriverCard(
      key: const Key('trafficReportCard'),
      title: 'Report Traffic',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('trafficCongested'),
                  onPressed: onReport == null ? null : () => onReport(true),
                  icon: const Icon(Icons.traffic, color: AppColors.error),
                  label: const Text('Congested'),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('trafficClear'),
                  onPressed: onReport == null ? null : () => onReport(false),
                  icon: const Icon(Icons.check_circle_outline, color: AppColors.shiftGreen),
                  label: const Text('Clear'),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              onReport == null
                  ? 'You can report traffic once your shift starts.'
                  : switch (reported) {
                      true => 'You reported congestion. It clears by itself after an hour.',
                      false => 'You reported the road is clear.',
                      null => 'Tell commuters if your route is slow right now.',
                    },
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
