// lib/widgets/commuter/route_code_chip.dart
//
// Teal pill with a route code ("07B"), shared by the route, vehicle and
// alert lists. [compact] is the smaller size used inside alert cards.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';

class RouteCodeChip extends StatelessWidget {
  const RouteCodeChip({super.key, required this.code, this.compact = false});

  final String code;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : AppSpacing.sm, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: AppColors.brandTeal,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(code, style: TextStyle(fontSize: compact ? 12 : 14, color: Colors.white)),
    );
  }
}
