// Driver dashboard view
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
import 'driver_reports_tab.dart';

/// Driver dashboard view
class DriverDashboardView extends StatefulWidget {
  /// Create driver dashboard
  const DriverDashboardView({super.key, required this.onSignOut, required this.profileService});

  final VoidCallback onSignOut;
  final ProfileService profileService;

  /// Create widget state
  @override
  State<DriverDashboardView> createState() => _DriverDashboardViewState();
}

/// Driver dashboard state
class _DriverDashboardViewState extends State<DriverDashboardView> {
  static const _navItems = [
    CommuterNavItem(icon: Icons.location_on_outlined, label: 'Map'),
    CommuterNavItem(icon: Icons.campaign_outlined, label: 'Reports'),
    CommuterNavItem(icon: AppIcons.navProfile, label: 'Profile'),
  ];
  static const _profileTab = 2;

  int _tab = 0;

  /// Select driver dashboard
  void _select(int tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      body: Column(
        children: [
          if (_tab != _profileTab) const CommuterHeader(),
          Expanded(
            child: switch (driver.loadState) {
              LoadState.idle || LoadState.loading => const Center(child: CircularProgressIndicator()),
              LoadState.error => _LoadError(message: driver.loadError, onRetry: driver.load),
              LoadState.ready => IndexedStack(
                  index: _tab,
                  children: [
                    DriverMapTab(driver: driver),
                    DriverReportsTab(driver: driver),
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

/// Load error widget
class _LoadError extends StatelessWidget {
  /// Create load error
  const _LoadError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  /// Build the widget
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
