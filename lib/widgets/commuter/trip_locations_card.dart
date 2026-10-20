// lib/widgets/commuter/trip_locations_card.dart
//
// "From" / "To" card on Plan Your Route, with a swap button between them.
// Purely presentational: the Route tab supplies labels and callbacks.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import 'commuter_field_box.dart';

class TripLocationsCard extends StatelessWidget {
  const TripLocationsCard({
    super.key,
    required this.fromValue,
    required this.toValue,
    required this.isLocating,
    this.usingMyLocation = false,
    this.destinationOnMap = false,
    required this.onChooseFrom,
    required this.onUseMyLocation,
    required this.onChooseTo,
    required this.onPickOnMap,
    this.onSwap,
    this.fromError,
    this.onOpenSettings,
  });

  /// Shown in the From box; null shows the "Your location" hint.
  final String? fromValue;
  final String? toValue;
  final bool isLocating;

  /// From is the commuter's own GPS location: the button shows as on.
  final bool usingMyLocation;

  /// To is a pin dropped on the map: the map button shows as on.
  final bool destinationOnMap;
  final String? fromError;

  final VoidCallback onChooseFrom;
  final VoidCallback onUseMyLocation;
  final VoidCallback onChooseTo;
  final VoidCallback onPickOnMap;

  /// Null disables the swap button (both ends must be set).
  final VoidCallback? onSwap;

  /// Shown next to [fromError] where the platform can open location settings.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final error = fromError;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        border: Border.all(color: AppColors.divider, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _EndLabel(label: 'From', color: AppColors.success),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: CommuterFieldBox(
                  hint: 'Your location',
                  value: fromValue,
                  onTap: onChooseFrom,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _StateIconButton(
                key: const Key('useMyLocation'),
                idleIcon: Icons.location_on_outlined,
                activeIcon: Icons.my_location,
                tooltip: 'Use my location',
                activeTooltip: 'Using your location (tap to update)',
                busyTooltip: 'Finding your location…',
                busy: isLocating,
                active: usingMyLocation,
                onPressed: onUseMyLocation,
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(error, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ),
                  if (onOpenSettings != null)
                    TextButton(onPressed: onOpenSettings, child: const Text('Open settings')),
                ],
              ),
            ),
          Center(
            child: IconButton(
              tooltip: 'Swap From and To',
              onPressed: onSwap,
              icon: const Icon(Icons.swap_horiz, size: 32),
            ),
          ),
          const _EndLabel(label: 'To', color: AppColors.error),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: CommuterFieldBox(
                  hint: 'Enter destination...',
                  value: toValue,
                  onTap: onChooseTo,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _StateIconButton(
                key: const Key('pickOnMap'),
                idleIcon: Icons.map_outlined,
                activeIcon: Icons.edit_location_alt,
                tooltip: 'Pick on map',
                activeTooltip: 'Move the pin on the map',
                active: destinationOnMap,
                onPressed: onPickOnMap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Round icon button with three looks: idle (grey circle, outlined icon),
/// busy (teal with a spinner) and active (teal with a white icon) — used for
/// "Use my location" (on while From is the commuter's GPS) and "Pick on
/// map" (on while To is a dropped pin). Tap again to update either.
class _StateIconButton extends StatelessWidget {
  const _StateIconButton({
    super.key,
    required this.idleIcon,
    required this.activeIcon,
    required this.tooltip,
    required this.activeTooltip,
    this.busyTooltip,
    this.busy = false,
    required this.active,
    required this.onPressed,
  });

  final IconData idleIcon;
  final IconData activeIcon;
  final String tooltip;
  final String activeTooltip;
  final String? busyTooltip;
  final bool busy;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Widget icon;
    if (busy) {
      icon = const SizedBox.square(
        key: ValueKey('busy'),
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      );
    } else if (active) {
      icon = Icon(activeIcon, key: const ValueKey('active'), size: 26, color: Colors.white);
    } else {
      icon = Icon(idleIcon, key: const ValueKey('idle'), size: 28, color: AppColors.textPrimary);
    }
    final filled = busy || active;

    return Tooltip(
      message: busy ? (busyTooltip ?? tooltip) : (active ? activeTooltip : tooltip),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? AppColors.brandTeal : const Color(0xFFF0F2F5),
          boxShadow: filled
              ? [BoxShadow(color: AppColors.brandTeal.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))]
              : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: busy ? null : onPressed,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child)),
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EndLabel extends StatelessWidget {
  const _EndLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.location_on_outlined, color: color, size: 22),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
