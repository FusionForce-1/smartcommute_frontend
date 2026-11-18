// Loading overlay
import 'package:flutter/material.dart';
import '../config/theme_config.dart';

/// Loading overlay
class LoadingOverlay extends StatelessWidget {
  /// Create loading overlay
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  /// Build the widget
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
