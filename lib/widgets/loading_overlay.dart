// lib/widgets/loading_overlay.dart
//
// E3. Flutter Reusable Widgets — LoadingOverlay
// Props: isLoading, child
// Wraps any screen during async operations (e.g. provider calls).

import 'package:flutter/material.dart';
import '../config/theme_config.dart';

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.25),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.secondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
