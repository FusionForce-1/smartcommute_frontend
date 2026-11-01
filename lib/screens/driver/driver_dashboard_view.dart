// lib/screens/driver/driver_dashboard_view.dart
//
// The driver app's screen: the logo header and three tabs — Map (the
// dashboard, and the map full screen), Updates, and Profile — with the
// bottom navigation. Reads DriverProvider from above. Every tab stays
// alive, so the map keeps its camera while browsing the others.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../providers/driver_provider.dart';
import '../../providers/load_state.dart';
import '../../services/profile_service.dart';
import '../../widgets/commuter/commuter_header.dart';
import '../../widgets/commuter/commuter_nav_bar.dart';
import 'driver_map_tab.dart';
import 'driver_profile_tab.dart';
import 'driver_updates_tab.dart';

class DriverDashboardView extends StatefulWidget {
  const DriverDashboardView({super.key, required this.onSignOut, required this.profileService});

  final VoidCallback onSignOut;
  final ProfileService profileService;

  @override
  State<DriverDashboardView> createState() => _DriverDashboardViewState();
}

class _DriverDashboardViewState extends State<DriverDashboardView> {
  static const _navItems = [
    CommuterNavItem(icon: Icons.location_on_outlined, label: 'Map'),
    CommuterNavItem(icon: Icons.published_with_changes, label: 'Updates'),
    CommuterNavItem(icon: AppIcons.navProfile, label: 'Profile'),
  ];
  static const _updatesTab = 1;
  static const _profileTab = 2;

  int _tab = 0;

  void _select(int tab) {
    if (tab == _tab) return;
    // Leaving Updates: what was there has now been seen.
    if (_tab == _updatesTab) context.read<DriverProvider>().markUpdatesRead();
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      body: Column(
        children: [
          // The Profile tab has its own teal header.
          if (_tab != _profileTab) const CommuterHeader(),
          Expanded(
            child: switch (driver.loadState) {
              LoadState.idle || LoadState.loading => const Center(child: CircularProgressIndicator()),
              LoadState.error => _LoadError(message: driver.loadError, onRetry: driver.load),
              LoadState.ready => IndexedStack(
                  index: _tab,
                  children: [
                    DriverMapTab(driver: driver),
                    DriverUpdatesTab(driver: driver),
                    DriverProfileTab(
                      driver: driver,
                      profileService: widget.profileService,
                      onSignOut: widget.onSignOut,
                    ),
                  ],
                ),
            },
          ),
        ],
      ),
      bottomNavigationBar: CommuterNavBar(items: _navItems, selectedIndex: _tab, onSelected: _select),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.navInactive),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message ?? "Couldn't load your dashboard.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.brandTeal),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
