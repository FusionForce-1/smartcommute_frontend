// fare breakdown sheet
import 'package:flutter/material.dart';

import '../config/theme_config.dart';
import '../constants/app_icons.dart';
import '../models/trip_plan.dart';

/// Show fare breakdown sheet
Future<void> showFareBreakdownSheet(BuildContext context, RouteOption option) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (context) => SafeArea(child: FareBreakdownSheet(option: option)),
  );
}

/// fare breakdown sheet
class FareBreakdownSheet extends StatelessWidget {
  /// Create fare breakdown sheet
  const FareBreakdownSheet({super.key, required this.option});

  final RouteOption option;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Fare estimate', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatFare(option.totalFare),
            style: textTheme.headlineMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${option.totalEtaMin} min · ${formatTransfers(option.transfers)}',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const Divider(height: AppSpacing.md),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: option.legs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) => _LegRow(leg: option.legs[index]),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Estimated fare — actual fare may vary.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Leg row
class _LegRow extends StatelessWidget {
  /// Create leg row
  const _LegRow({required this.leg});

  final RouteLeg leg;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(AppIcons.vehicle, color: AppColors.secondary),
      title: Text(leg.routeName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Board at ${leg.boardLabel} → Alight at ${leg.alightLabel}',
          ),
          Text('${leg.etaMin} min'),
        ],
      ),
      trailing: Text(
        formatFare(leg.fare),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
