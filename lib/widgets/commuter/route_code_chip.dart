// lib/widgets/commuter/route_code_chip.dart
//
// Teal pill with a route code ("07B"), shared by the route and vehicle lists.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';

class RouteCodeChip extends StatelessWidget {
  const RouteCodeChip({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandTeal,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(code, style: const TextStyle(fontSize: 14, color: Colors.white)),
    );
  }
}
