// lib/widgets/driver/driver_buttons.dart
//
// The dashboard's two full-width buttons: START SHIFT (green) and
// View My Route on Map (blue outline).

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';

class StartShiftButton extends StatelessWidget {
  const StartShiftButton({super.key, required this.onPressed, this.busy = false});

  /// Null disables the button (e.g. no vehicle assigned).
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
          : const Icon(Icons.play_circle_outline, size: 30),
      label: const Text('START SHIFT'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.shiftGreen,
        disabledBackgroundColor: AppColors.shiftGreen.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }
}

class ViewRouteButton extends StatelessWidget {
  const ViewRouteButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      // near_me points up-right; the design's arrow points up-left.
      icon: Transform.flip(flipX: true, child: const Icon(Icons.near_me, size: 28)),
      label: const Text('View My Route on Map'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.infoBlue,
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: AppColors.infoBlue, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 19),
      ),
    );
  }
}
