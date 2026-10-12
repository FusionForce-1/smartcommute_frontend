// lib/widgets/commuter/recent_searches.dart
//
// "Recent Searches" list on Plan Your Route; tapping one reuses it as the
// destination. Renders nothing until the commuter has searched.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/trip_plan.dart';

class RecentSearches extends StatelessWidget {
  const RecentSearches({
    super.key,
    required this.places,
    required this.onSelected,
  });

  final List<TripPlace> places;
  final ValueChanged<TripPlace> onSelected;

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Recent Searches',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final place in places)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: AppColors.divider, width: 1.4),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                leading: const Icon(Icons.schedule, color: AppColors.textSecondary),
                title: Text(
                  place.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, color: AppColors.textSecondary),
                ),
                onTap: () => onSelected(place),
              ),
            ),
          ),
      ],
    );
  }
}
