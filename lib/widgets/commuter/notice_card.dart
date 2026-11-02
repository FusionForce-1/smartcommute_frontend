// lib/widgets/commuter/notice_card.dart
//
// One notice on the Notifications screen. Unread notices are tinted in
// their colour with a dot before the title; read ones turn white.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/commuter_notice.dart';
import '../../utils/time_ago.dart';
import 'notice_style.dart';
import 'route_code_chip.dart';

class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.notice, required this.onTap});

  final CommuterNotice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = NoticeStyle.of(notice);
    final unread = !notice.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: unread ? style.background : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          side: BorderSide(color: unread ? style.color : AppColors.divider, width: 1.4),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 8, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NoticeIcon(style: style),
                const SizedBox(width: 12),
                Expanded(child: _NoticeBody(notice: notice, style: style, unread: unread)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeIcon extends StatelessWidget {
  const _NoticeIcon({required this.style});

  final NoticeStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: style.color, width: 1.4),
      ),
      child: Icon(style.icon, color: style.color, size: 26),
    );
  }
}

class _NoticeBody extends StatelessWidget {
  const _NoticeBody({required this.notice, required this.style, required this.unread});

  final CommuterNotice notice;
  final NoticeStyle style;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final company = notice.companyName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (unread) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                notice.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.schedule, size: 14, color: AppColors.navInactive),
            const SizedBox(width: 3),
            Text(
              timeAgo(notice.createdAt),
              style: const TextStyle(fontSize: 11, color: AppColors.navInactive),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.navInactive),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            RouteCodeChip(code: noticeRoutes(notice), compact: true),
            Text(style.label, style: TextStyle(fontSize: 12, color: style.color, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          notice.message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.3),
        ),
        if (company != null) ...[
          const SizedBox(height: 4),
          Text('From $company', style: const TextStyle(fontSize: 12, color: AppColors.navInactive)),
        ],
      ],
    );
  }
}
