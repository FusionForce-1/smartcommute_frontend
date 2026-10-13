// lib/widgets/commuter/alert_style.dart
//
// Colour and icon for each kind of transit alert, shared by the alert
// card and its details sheet. Resolved alerts read as "cleared" (green)
// whatever their original severity.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/commuter_alert.dart';

class AlertStyle {
  const AlertStyle._(this.color, this.icon, this.label);

  final Color color;
  final IconData icon;
  final String label;

  /// Light tint of [color] on white (opaque, so the page colour can't show through).
  Color get background => Color.alphaBlend(color.withValues(alpha: 0.07), Colors.white);

  static const _critical = AlertStyle._(AppColors.error, Icons.cancel_outlined, 'Critical');
  static const _warning = AlertStyle._(AppColors.accent, Icons.warning_amber_rounded, 'Warning');
  static const _info = AlertStyle._(AppColors.infoBlue, Icons.campaign_outlined, 'Info');
  static const _resolved = AlertStyle._(AppColors.success, Icons.check_circle_outline, 'Resolved');

  static AlertStyle of(CommuterAlert alert) {
    if (alert.isResolved) return _resolved;
    return switch (alert.severity) {
      AlertSeverity.critical => _critical,
      AlertSeverity.warning => _warning,
      AlertSeverity.info => _info,
    };
  }
}
