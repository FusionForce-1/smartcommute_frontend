// Commuter primary button
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';

/// Commuter primary button
class CommuterPrimaryButton extends StatelessWidget {
  /// Create commuter primary button
  const CommuterPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brandTeal,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.divider,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}
