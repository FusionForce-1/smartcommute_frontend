// lib/screens/commuter/commuter_dashboard.dart
//
// Emae D. Calonia — Commuter test dashboard scaffold.
// Bottom navigation: Map, Routes, Feedback, Profile.
// Placeholder tab bodies for navigation / layout testing.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../providers/auth_provider.dart';
import '../../router/app_router.dart';
class CommuterDashboard extends StatefulWidget {
  const CommuterDashboard({super.key, this.isGuest = false});

  /// True when opened via "Continue as Guest" — profile actions stay disabled.
  final bool isGuest;

  @override
  State<CommuterDashboard> createState() => _CommuterDashboardState();
}

class _CommuterDashboardState extends State<CommuterDashboard> {
  int _currentIndex = 0;

  static const _tabs = [
    _CommuterTab(
      label: 'Map',
      icon: AppIcons.location,
      title: 'Live Map',
      description: 'Leaflet map with vehicle markers and stop pins.',
    ),
    _CommuterTab(
      label: 'Routes',
      icon: AppIcons.routeStop,
      title: 'Trip Planner',
      description: 'Origin / destination search and ranked route options.',
    ),
    _CommuterTab(
      label: 'Feedback',
      icon: AppIcons.feedback,
      title: 'Submit Feedback',
      description: 'Report delays, overcrowding, or route issues.',
    ),
    _CommuterTab(
      label: 'Profile',
      icon: AppIcons.profileAvatar,
      title: 'My Profile',
      description: 'Account details, preferences, and sign-out.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tab = _tabs[_currentIndex];

    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(tab.title),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.notificationBell),
            tooltip: 'Announcements',
            onPressed: () {
              // TODO [Velez]: Wire with API/State Provider here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Announcements (preview)')),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(_tabs.length, (index) {
          return _CommuterTabPlaceholder(
            tab: _tabs[index],
            isGuest: widget.isGuest && index == 3,
          );
        }),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}

class _CommuterTab {
  const _CommuterTab({
    required this.label,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String label;
  final IconData icon;
  final String title;
  final String description;
}

class _CommuterTabPlaceholder extends StatelessWidget {
  const _CommuterTabPlaceholder({
    required this.tab,
    required this.isGuest,
  });

  final _CommuterTab tab;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: tab.label == 'Map' ? 220 : 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, size: 48, color: AppColors.secondary),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${tab.label} view placeholder',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Text(
                      tab.description,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (tab.label == 'Map') ...[
            _PreviewActionTile(
              icon: AppIcons.myLocation,
              label: 'Center on my location',
              onTap: () {
                // TODO [Velez]: Wire with API/State Provider here
              },
            ),
            _PreviewActionTile(
              icon: AppIcons.vehicle,
              label: 'Refresh vehicle markers',
              onTap: () {
                // TODO [Velez]: Wire with API/State Provider here
              },
            ),
          ],
          if (tab.label == 'Routes') ...[
            _PreviewActionTile(
              icon: AppIcons.search,
              label: 'Plan a trip',
              onTap: () {
                // TODO [Velez]: Wire with API/State Provider here
              },
            ),
            _PreviewActionTile(
              icon: AppIcons.fare,
              label: 'View fare estimate',
              onTap: () {
                // TODO [Velez]: Wire with API/State Provider here
              },
            ),
          ],
          if (tab.label == 'Feedback') ...[
            _PreviewActionTile(
              icon: AppIcons.feedback,
              label: 'Open feedback form',
              onTap: () {
                // TODO [Velez]: Wire with API/State Provider here
              },
            ),
          ],
          if (tab.label == 'Profile') ...[
            if (isGuest)
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: const Text(
                  'Guest mode — sign in to access profile and saved trips.',
                  style: TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            _PreviewActionTile(
              icon: AppIcons.settings,
              label: 'Account settings',
              enabled: !isGuest,
              onTap: () {
                // TODO [Velez]: Wire with API/State Provider here
              },
            ),
            _PreviewActionTile(
              icon: AppIcons.logout,
              label: 'Sign out',
              onTap: () async {
                  await context.read<AuthProvider>().logout();

                     if (!context.mounted) return;

              Navigator.of(context).pushAndRemoveUntil(
                   MaterialPageRoute(
                    builder: (_) => const LoginScreenHost(),
                    ),
      (route) => false,
    );
  },
),
          ],
        ],
      ),
    );
  }
}

class _PreviewActionTile extends StatelessWidget {
  const _PreviewActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        enabled: enabled,
        leading: Icon(icon, color: AppColors.secondary),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
