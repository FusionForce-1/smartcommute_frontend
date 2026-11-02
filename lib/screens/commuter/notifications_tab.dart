// lib/screens/commuter/notifications_tab.dart
//
// Notifications tab: what operators sent about the routes the commuter
// saved or rode — unread count, Mark all read, category filters, Load more.
// Tapping a notice marks it read and opens its details. Pull down to
// refresh. Guests have no inbox and are invited to sign up instead. State
// lives in NoticesProvider (owned by the dashboard).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../models/commuter_notice.dart';
import '../../providers/load_state.dart';
import '../../providers/notices_provider.dart';
import '../../widgets/commuter/notice_card.dart';
import '../../widgets/commuter/notice_details_sheet.dart';
import '../../widgets/commuter/notice_filter_bar.dart';

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key, this.onCreateAccount});

  /// Guests: leave the guest visit and open Register.
  final VoidCallback? onCreateAccount;

  void _open(BuildContext context, CommuterNotice notice) {
    context.read<NoticesProvider>().markRead(notice);
    showNoticeDetailsSheet(context, notice);
  }

  Future<void> _markAllRead(BuildContext context) async {
    final error = await context.read<NoticesProvider>().markAllRead();
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notices = context.watch<NoticesProvider>();

    if (notices.isGuest) return _GuestInvite(onCreateAccount: onCreateAccount);

    return RefreshIndicator(
      onRefresh: notices.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const Text(
            'Notifications',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '${notices.unreadCount} unread',
                style: const TextStyle(fontSize: 17, color: AppColors.textPrimary),
              ),
              const Spacer(),
              TextButton(
                onPressed: notices.unreadCount == 0 ? null : () => _markAllRead(context),
                style: TextButton.styleFrom(foregroundColor: AppColors.brandTeal),
                child: const Text('Mark all read', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          NoticeFilterBar(selected: notices.filter, onSelected: notices.setFilter),
          const SizedBox(height: AppSpacing.md),
          ..._content(context, notices),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, NoticesProvider notices) {
    switch (notices.state) {
      case LoadState.idle:
      case LoadState.loading:
        return const [
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      case LoadState.error:
        return [
          _Message(
            icon: AppIcons.errorRetry,
            text: notices.errorMessage ?? "Couldn't load your notifications.",
            color: AppColors.error,
            onRetry: notices.load,
          ),
        ];
      case LoadState.ready:
        final list = notices.notices;
        if (list.isEmpty) {
          return [
            _Message(
              icon: AppIcons.navAlerts,
              text: notices.filter == NoticeFilter.all
                  ? 'No notifications yet. Save a route or plan a trip to get updates from its operator.'
                  : 'No ${notices.filter.label.toLowerCase()} right now.',
            ),
          ];
        }
        return [
          for (final notice in list) NoticeCard(notice: notice, onTap: () => _open(context, notice)),
          if (notices.hasMore)
            Center(
              child: notices.loadingMore
                  ? const Padding(padding: EdgeInsets.all(AppSpacing.sm), child: CircularProgressIndicator())
                  : TextButton(
                      key: const Key('loadMoreNotices'),
                      onPressed: notices.loadMore,
                      style: TextButton.styleFrom(foregroundColor: AppColors.brandTeal),
                      child: const Text('Load more'),
                    ),
            ),
        ];
    }
  }
}

class _GuestInvite extends StatelessWidget {
  const _GuestInvite({required this.onCreateAccount});

  final VoidCallback? onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final onCreateAccount = this.onCreateAccount;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const Text(
          'Notifications',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        ),
        const _Message(
          icon: AppIcons.navAlerts,
          text: 'Sign in to get notifications from the operators of the routes you ride.',
        ),
        if (onCreateAccount != null)
          Center(
            child: FilledButton(
              onPressed: onCreateAccount,
              style: FilledButton.styleFrom(backgroundColor: AppColors.brandTeal),
              child: const Text('Create account'),
            ),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.color = AppColors.textSecondary,
    this.onRetry,
  });

  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final onRetry = this.onRetry;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Icon(icon, size: 44, color: color),
          const SizedBox(height: AppSpacing.xs),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 15)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
