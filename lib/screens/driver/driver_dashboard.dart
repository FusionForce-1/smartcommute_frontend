// lib/screens/driver/driver_dashboard.dart
//
// Emae D. Calonia — Driver test dashboard scaffold.
// Card-based layout with GPS session toggle and route status triggers.

import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  bool _gpsSessionActive = false;
  String _routeStatus = 'active';

  void _toggleGps(bool value) {
    setState(() => _gpsSessionActive = value);
    // TODO [Velez]: Wire with API/State Provider here
    // Start/stop GPS WebSocket session and background location updates.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'GPS session started (preview)' : 'GPS session stopped (preview)',
        ),
      ),
    );
  }

  void _setRouteStatus(String status) {
    setState(() => _routeStatus = status);
    // TODO [Velez]: Wire with API/State Provider here
    // ApiService.updateRouteStatus(RouteStatusUpdate(...))
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Route status → $status (preview)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.logout),
            tooltip: 'Sign out',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _DriverCard(
            title: 'GPS Session',
            subtitle: _gpsSessionActive
                ? 'Broadcasting location to fleet map'
                : 'Location sharing is off',
            leading: Icon(
              _gpsSessionActive ? AppIcons.gpsToggleOn : AppIcons.gpsToggleOff,
              color: _gpsSessionActive ? AppColors.success : AppColors.textSecondary,
              size: 36,
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable GPS broadcast'),
              subtitle: const Text('Required while on an active route'),
              value: _gpsSessionActive,
              activeThumbColor: AppColors.secondary,
              onChanged: _toggleGps,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _DriverCard(
            title: 'Assigned Route',
            subtitle: 'Route 12 — Downtown Loop (preview)',
            leading: const Icon(AppIcons.routeStop, color: AppColors.secondary, size: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InfoRow(label: 'Vehicle', value: 'ABC-1234'),
                _InfoRow(label: 'Next stop', value: 'Central Terminal'),
                _InfoRow(label: 'ETA', value: '4 min'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _DriverCard(
            title: 'Route Status',
            subtitle: 'Current: ${_statusLabel(_routeStatus)}',
            leading: Icon(
              _statusIcon(_routeStatus),
              color: _statusColor(_routeStatus),
              size: 36,
            ),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _StatusChip(
                  label: 'Active',
                  selected: _routeStatus == 'active',
                  color: AppColors.success,
                  onTap: () => _setRouteStatus('active'),
                ),
                _StatusChip(
                  label: 'Congested',
                  selected: _routeStatus == 'congested',
                  color: AppColors.accent,
                  onTap: () => _setRouteStatus('congested'),
                ),
                _StatusChip(
                  label: 'Suspended',
                  selected: _routeStatus == 'suspended',
                  color: AppColors.error,
                  onTap: () => _setRouteStatus('suspended'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _DriverCard(
            title: 'Quick Actions',
            subtitle: 'Test triggers for driver workflows',
            leading: const Icon(AppIcons.vehicle, color: AppColors.secondary, size: 36),
            child: Column(
              children: [
                _ActionButton(
                  icon: AppIcons.speed,
                  label: 'Report speed / heading',
                  onPressed: () {
                    // TODO [Velez]: Wire with API/State Provider here
                  },
                ),
                _ActionButton(
                  icon: AppIcons.crowdMedium,
                  label: 'Update crowd level',
                  onPressed: () {
                    // TODO [Velez]: Wire with API/State Provider here
                  },
                ),
                _ActionButton(
                  icon: AppIcons.signalLost,
                  label: 'Simulate signal loss',
                  onPressed: () {
                    // TODO [Velez]: Wire with API/State Provider here
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
        'active' => 'Active',
        'congested' => 'Congested',
        'suspended' => 'Suspended',
        _ => status,
      };

  static IconData _statusIcon(String status) => switch (status) {
        'active' => AppIcons.statusActive,
        'congested' => AppIcons.statusCongested,
        'suspended' => AppIcons.statusSuspended,
        _ => AppIcons.statusActive,
      };

  static Color _statusColor(String status) => switch (status) {
        'active' => AppColors.success,
        'congested' => AppColors.accent,
        'suspended' => AppColors.error,
        _ => AppColors.textSecondary,
      };
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget leading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.2),
      checkmarkColor: color,
      onSelected: (_) => onTap(),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}
