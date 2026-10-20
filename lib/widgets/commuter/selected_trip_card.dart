// lib/widgets/commuter/selected_trip_card.dart
//
// Home tab card for the route picked with "Select this route": which PUV,
// where to board and alight, fare and time. Tap it for the full details;
// the ✕ cancels the selection.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/selected_trip.dart';
import '../../models/trip_plan.dart';

class SelectedTripCard extends StatelessWidget {
  const SelectedTripCard({
    super.key,
    required this.trip,
    required this.onCancel,
    required this.onOpen,
  });

  final SelectedTrip trip;
  final VoidCallback onCancel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final option = trip.option;
    return Material(
      key: const Key('selectedTripCard'),
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        side: const BorderSide(color: AppColors.brandTeal, width: 1.4),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.brandTeal,
                foregroundColor: Colors.white,
                child: Icon(Icons.directions_bus),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SELECTED ROUTE',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandTeal,
                      ),
                    ),
                    Text(
                      option.routeSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trip.boardToAlight,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatFare(option.totalFare)} · ${option.totalEtaMin} min · '
                      '${formatTransfers(option.transfers)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cancel selected route',
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
