// Crowd chip
import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';

/// Crowd level chip
class CrowdChip extends StatelessWidget {
  /// Create crowd chip
  const CrowdChip({super.key, required this.level});

  final String? level;

  static const Map<String, (String, IconData, Color)> _looks = {
    'low': ('Seats available', AppIcons.crowdLow, AppColors.shiftGreen),
    'medium': ('Filling up', AppIcons.crowdMedium, Color(0xFFB26A00)),
    'high': ('Nearly full', AppIcons.crowdHigh, AppColors.error),
  };

  /// Label for level
  static String? labelFor(String? level) => _looks[level]?.$1;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final look = _looks[level];
    if (look == null) return const SizedBox.shrink();
    final (label, icon, color) = look;
    return Semantics(
      label: 'Crowd: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
