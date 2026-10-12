// lib/widgets/commuter/commuter_primary_button.dart
//
// Full-width teal call-to-action ("Find Routes", "View Selected Route on Map").
// Pass a null [onPressed] to disable it.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';

class CommuterPrimaryButton extends StatelessWidget {
  const CommuterPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

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
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}
