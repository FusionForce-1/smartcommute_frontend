// lib/widgets/commuter/notice_details_sheet.dart
//
// Full text of an operator notice, opened by tapping its card.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../models/commuter_notice.dart';
import '../../utils/time_ago.dart';
import 'notice_style.dart';
import 'route_code_chip.dart';

Future<void> showNoticeDetailsSheet(BuildContext context, CommuterNotice notice) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => SafeArea(child: NoticeDetailsSheet(notice: notice)),
  );
}

class NoticeDetailsSheet extends StatelessWidget {
  const NoticeDetailsSheet({super.key, required this.notice});

  final CommuterNotice notice;

  @override
  Widget build(BuildContext context) {
    final style = NoticeStyle.of(notice);
    final source = notice.companyName;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(style.icon, color: style.color),
              const SizedBox(width: AppSpacing.xs),
              Text(style.label, style: TextStyle(color: style.color, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(notice.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          RouteCodeChip(code: noticeRoutes(notice)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            notice.message,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ['Posted · ${timeAgo(notice.createdAt)}', if (source != null) source].join(' · '),
            style: const TextStyle(fontSize: 13, color: AppColors.navInactive),
          ),
        ],
      ),
    );
  }
}
