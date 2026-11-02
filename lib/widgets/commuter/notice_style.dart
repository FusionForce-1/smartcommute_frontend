// lib/widgets/commuter/notice_style.dart
//
// Colour, icon and label for each kind of operator notice, shared by the
// notice card and its details sheet. Service alerts are coloured by
// severity; schedule changes and promotions have their own look.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/commuter_notice.dart';

class NoticeStyle {
  const NoticeStyle._(this.color, this.icon, this.label);

  final Color color;
  final IconData icon;
  final String label;

  /// Light tint of [color] on white (opaque, so the page colour can't show through).
  Color get background => Color.alphaBlend(color.withValues(alpha: 0.07), Colors.white);

  static const _critical = NoticeStyle._(AppColors.error, Icons.cancel_outlined, 'Critical alert');
  static const _warning = NoticeStyle._(AppColors.accent, Icons.warning_amber_rounded, 'Warning');
  static const _info = NoticeStyle._(AppColors.infoBlue, Icons.campaign_outlined, 'Service alert');
  static const _schedule = NoticeStyle._(AppColors.brandTeal, Icons.schedule, 'Schedule change');
  static const _promotion = NoticeStyle._(AppColors.success, Icons.local_offer_outlined, 'Promotion');

  static NoticeStyle of(CommuterNotice notice) => switch (notice.category) {
        NoticeCategory.scheduleChange => _schedule,
        NoticeCategory.promotion => _promotion,
        NoticeCategory.serviceAlert => switch (notice.severity) {
            NoticeSeverity.critical => _critical,
            NoticeSeverity.warning => _warning,
            NoticeSeverity.info => _info,
          },
      };
}

/// "J01, J02", or "Your routes" when the operator's routes have no codes.
String noticeRoutes(CommuterNotice notice) =>
    notice.routeCodes.isEmpty ? 'Your routes' : notice.routeCodes.join(', ');
