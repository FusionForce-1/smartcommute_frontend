// Driver profile tab
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../models/driver_dashboard.dart';
import '../../providers/driver_provider.dart';
import '../../services/profile_service.dart';
import '../../widgets/auth/consent_checkbox.dart' show showLegalChoices;
import '../../widgets/commuter/profile_header.dart' show ProfileAvatar, RoleBadge;
import '../../widgets/commuter/settings_group.dart';
import '../commuter/help_support_screen.dart';
import '../commuter/privacy_security_screen.dart';

/// Driver profile tab
class DriverProfileTab extends StatelessWidget {
  /// Create driver profile tab
  const DriverProfileTab({
    super.key,
    required this.driver,
    required this.profileService,
    required this.onSignOut,
  });

  final DriverProvider driver;

  final ProfileService profileService;
  final VoidCallback onSignOut;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final vehicles = driver.vehicles;
    final operator = driver.operator;
    final recent = driver.recentRoute;

    return RefreshIndicator(
      onRefresh: driver.refresh,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _DriverHeader(driver: driver),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionTitle(vehicles.length > 1 ? 'My Routes' : 'My Route'),
                if (vehicles.isEmpty)
                  const _EmptyCard('No vehicle assigned yet — ask your operator.')
                else
                  _Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < vehicles.length; i++) ...[
                          if (i > 0) const Divider(height: AppSpacing.md),
                          _RouteRow(vehicle: vehicles[i], onShift: vehicles[i].id == driver.shift?.vehicleId),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                const _SectionTitle('My Operator'),
                _OperatorCard(operator: operator),
                const SizedBox(height: AppSpacing.md),
                const _SectionTitle('Recent Route'),
                if (recent == null)
                  const _EmptyCard('Your last finished shift shows here.')
                else
                  _Card(child: _RouteRow(vehicle: recent)),
                const SizedBox(height: AppSpacing.md),
                const _SectionTitle('Account'),
                SettingsGroup(
                  children: [
                    SettingsLinkRow(
                      icon: Icons.shield_outlined,
                      label: 'Privacy & Security',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => PrivacySecurityScreen(service: profileService),
                      )),
                    ),
                    SettingsLinkRow(
                      icon: Icons.help_outline,
                      label: 'Help & Support',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => const HelpSupportScreen(faqs: HelpSupportScreen.driverFaqs),
                      )),
                    ),
                    SettingsLinkRow(
                      icon: Icons.description_outlined,
                      label: 'Terms & Privacy Policy',
                      onTap: () => showLegalChoices(context),
                    ),
                    SettingsLinkRow(
                      icon: AppIcons.logout,
                      label: 'Sign out',
                      color: AppColors.error,
                      onTap: onSignOut,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Driver header
class _DriverHeader extends StatelessWidget {
  /// Create driver header
  const _DriverHeader({required this.driver});

  final DriverProvider driver;

  /// Initials of
  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final vehicle = driver.vehicle;
    final email = driver.email;
    const detail = TextStyle(fontSize: 13, color: Colors.white);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.brandTeal,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppSpacing.lg)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
            child: Row(
              children: [
                ProfileAvatar(initials: initialsOf(driver.name), size: 84),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      if (email != null) Text(email, overflow: TextOverflow.ellipsis, style: detail),
                      Text('Route: ${vehicle?.routeCode ?? '—'}', style: detail),
                      Text('Vehicle: ${vehicle?.plateNumber ?? 'Not assigned'}', style: detail),
                      const SizedBox(height: AppSpacing.xs),
                      const RoleBadge(label: 'Driver'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section title widget
class _SectionTitle extends StatelessWidget {
  /// Create section title
  const _SectionTitle(this.title);

  final String title;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      ),
    );
  }
}

/// Card widget
class _Card extends StatelessWidget {
  /// Create card
  const _Card({required this.child});

  final Widget child;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.divider, width: 1.4),
      ),
      child: child,
    );
  }
}

/// Empty card
class _EmptyCard extends StatelessWidget {
  /// Create empty card
  const _EmptyCard(this.text);

  final String text;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return _Card(child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)));
  }
}

/// Route row
class _RouteRow extends StatelessWidget {
  /// Create route row
  const _RouteRow({required this.vehicle, this.onShift = false});

  final AssignedVehicle vehicle;
  final bool onShift;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.brandTeal, width: 1.4),
          ),
          child: const Icon(Icons.location_on_outlined, size: 20, color: AppColors.brandTeal),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${vehicle.routeCode ?? 'Route'} · ${vehicle.plateNumber}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Text(vehicle.routeLine, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
        if (onShift)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.shiftGreenTint,
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: const Text('On shift', style: TextStyle(fontSize: 12, color: AppColors.shiftGreen)),
          ),
      ],
    );
  }
}

/// Operator card
class _OperatorCard extends StatelessWidget {
  /// Create operator card
  const _OperatorCard({required this.operator});

  final DriverOperator? operator;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final company = operator?.companyName;
    final owner = operator?.ownerName;
    if (company == null && owner == null) return const _EmptyCard('Operator details unavailable.');
    const label = TextStyle(fontSize: 13, color: AppColors.textSecondary);
    const value = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary);

    return _Card(
      child: IntrinsicHeight(
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.brandTeal,
              child: Text(
                (company ?? owner ?? '?').characters.first.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Company Name', style: label),
                  Text(company ?? '—', style: value, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const VerticalDivider(color: AppColors.divider, thickness: 1.4, width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Account Owner', style: label),
                  Text(owner ?? '—', style: value, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
