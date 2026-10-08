import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../models/fleet.dart';
import '../../services/dio_interceptor.dart';
import '../../services/drivers_service.dart';
import '../../services/fleet_service.dart';
import 'operator_vehicles.dart';

class OperatorDashboard extends StatefulWidget {
  const OperatorDashboard({super.key, this.dio});

  /// Injected in tests; defaults to the authenticated app client.
  final Dio? dio;

  @override
  State<OperatorDashboard> createState() => _OperatorDashboardState();
}

class _OperatorDashboardState extends State<OperatorDashboard> {
  int _selectedIndex = 0;

  late final FleetService _fleetService;
  late final DriversService _driversService;
  Timer? _refreshTimer;

  bool _loading = true;
  List<FleetVehicle>? _fleet;
  String? _fleetError;
  Map<String, RouteSummary> _routes = const {};
  int? _driverCount;
  List<Announcement>? _announcements;
  String? _announcementsError;

  @override
  void initState() {
    super.initState();
    final dio = widget.dio ?? buildDioClient();
    _fleetService = FleetService(dio);
    _driversService = DriversService(dio);
    _loadDashboard();
    // Keeps statuses and "Last Ping" current while the dashboard is open.
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_selectedIndex == 0 && !_loading) _loadDashboard();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);

    // Each section loads on its own so one failing endpoint doesn't
    // blank the whole dashboard.
    final results = await Future.wait<Object?>([
      _fleetService.getFleet().then<Object?>((v) => v, onError: (Object e) => e),
      _fleetService.getRoutes().then<Object?>((v) => v, onError: (Object e) => e),
      _driversService.getDrivers().then<Object?>((v) => v, onError: (Object e) => e),
      _fleetService.getAnnouncements().then<Object?>((v) => v, onError: (Object e) => e),
    ]);
    if (!mounted) return;

    final fleet = results[0];
    final routes = results[1];
    final drivers = results[2];
    final announcements = results[3];

    setState(() {
      _loading = false;

      if (fleet is List<FleetVehicle>) {
        _fleet = fleet;
        _fleetError = null;
      } else {
        _fleetError = driverErrorMessage(fleet!, 'Unable to load fleet data.');
      }
      if (routes is Map<String, RouteSummary>) _routes = routes;
      if (drivers is List) _driverCount = drivers.length;
      if (announcements is List<Announcement>) {
        _announcements = announcements;
        _announcementsError = null;
      } else {
        _announcementsError =
            driverErrorMessage(announcements!, 'Unable to load announcements.');
      }
    });
  }

  static const Color sidebarColor = Color(0xFFDCECF2);
  static const Color primaryColor = Color(0xFF2F8F99);
  static const Color pageColor = Color(0xFFF4F7F9);
  static const Color textColor = Color(0xFF163B50);

  static const List<String> _menuItems = [
    'Dashboard',
    'Fleet',
    'Routes',
    'Alerts',
    'Profile',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor,
      body: Row(
        children: [
          _buildSidebar(),

          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 282,
      color: sidebarColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 22),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Image.asset(
              'assets/images/smart_commute_logo.png',
              height: 70,
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(height: 22),

          for (int index = 0; index < _menuItems.length; index++)
            _buildSidebarItem(index),

          const Spacer(),

          const Divider(
            height: 1,
            color: Color(0xFFC8DCE3),
          ),

          _buildBottomSidebarItem(
            icon: Icons.logout,
            label: 'Log Out',
            onTap: () {},
          ),

          _buildBottomSidebarItem(
            icon: Icons.help_outline,
            label: 'Help',
            onTap: () {},
          ),

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index) {
    final bool selected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 3,
      ),
      child: Material(
        color: selected ? primaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () {
            final reload = index == 0 && _selectedIndex != 0 && !_loading;
            setState(() {
              _selectedIndex = index;
            });
            if (reload) _loadDashboard();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: Row(
              children: [
                Icon(
                  _menuIcon(index),
                  size: 22,
                  color: selected ? Colors.white : textColor,
                ),
                const SizedBox(width: 16),
                Text(
                  _menuItems[index],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Colors.white : textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSidebarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 2,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: textColor,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    // Fleet draws its own full-width top bar, so it skips the page padding.
    if (_selectedIndex == 1) return const OperatorVehicles();

    return Container(
      color: pageColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          40,
          28,
          32,
          24,
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 1:
        return const OperatorVehicles();

      case 2:
        return _placeholder(
          'Routes',
          'View and manage transportation routes.',
          Icons.navigation_outlined,
        );

      case 3:
        return _placeholder(
          'Alerts',
          'Monitor important fleet and vehicle alerts.',
          Icons.notifications_none,
        );

      case 4:
        return _placeholder(
          'Profile',
          'Manage your operator profile.',
          Icons.person_outline,
        );

      case 5:
        return _placeholder(
          'Settings',
          'Manage your operator settings.',
          Icons.settings_outlined,
        );

      default:
        return _dashboardHome();
    }
  }

  Widget _dashboardHome() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_fleetError != null) _buildErrorBanner(),
            _buildSummaryCards(),
            const SizedBox(height: 30),
            _buildActiveFleet(),
            const SizedBox(height: 30),
            _buildAnnouncementManagement(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDEE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE53935)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _fleetError!,
              style: const TextStyle(color: Color(0xFFE53935), fontSize: 15),
            ),
          ),
          TextButton(
            onPressed: _loadDashboard,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final now = DateTime.now();
    final fleet = _fleet;
    final drivers = _driverCount;

    String count(int? value) => _loading && value == null ? '—' : '${value ?? 0}';

    final activeVehicles = fleet?.where((v) => v.isActive).length;
    final activeRoutes =
        fleet?.where((v) => v.isActive).map((v) => v.routeId).toSet().length;
    final routeCount = fleet?.map((v) => v.routeId).toSet().length;
    final pinged = fleet
        ?.where((v) => v.hasRecentPing(now, window: const Duration(hours: 1)))
        .length;
    final coverage = (fleet == null || fleet.isEmpty)
        ? (_loading ? '—' : '0%')
        : '${(pinged! * 100 / fleet.length).round()}%';

    final cards = [
      _summaryCard(
        title: 'Active Vehicles',
        value: count(activeVehicles),
        caption: fleet == null ? null : 'of ${fleet.length} registered',
      ),
      _summaryCard(
        title: 'Active Routes',
        value: count(activeRoutes),
        caption: routeCount == null ? null : 'of $routeCount assigned',
      ),
      _summaryCard(
        title: 'Registered Drivers',
        value: count(drivers),
        caption: drivers == null ? null : 'in your roster',
      ),
      _summaryCard(
        title: 'GPS Coverage',
        value: coverage,
        caption: fleet == null ? null : 'reported in the last hour',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width < 900) {
          return Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              for (final card in cards)
                SizedBox(width: (width - 18) / 2, child: card),
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 20),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    String? caption,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.symmetric(
        horizontal: 30,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE1E7EA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF68777F),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 36,
              height: 1,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8A969D),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveFleet() {
    final fleet = _fleet ?? const <FleetVehicle>[];
    final now = DateTime.now();

    Widget body;
    if (_loading && _fleet == null) {
      body = const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (fleet.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(
            _fleetError != null
                ? 'Fleet data is unavailable.'
                : 'No vehicles registered yet.',
            style: const TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ),
      );
    } else {
      body = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 56,
          dataRowMinHeight: 62,
          dataRowMaxHeight: 62,
          horizontalMargin: 30,
          columnSpacing: 54,
          headingTextStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF53636B),
          ),
          dataTextStyle: const TextStyle(
            fontSize: 15,
            color: Color(0xFF233B49),
          ),
          columns: const [
            DataColumn(label: Text('Vehicle')),
            DataColumn(label: Text('Route')),
            DataColumn(label: Text('Crowd')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Last Ping')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final vehicle in fleet)
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      vehicle.plateNumber,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataCell(Text(_routeLabel(vehicle.routeId))),
                  DataCell(Text(_crowdLabel(vehicle.crowdLevel))),
                  DataCell(_vehicleStatus(vehicle, now)),
                  DataCell(
                    Text(
                      vehicle.lastPing == null
                          ? 'Never'
                          : timeAgo(vehicle.lastPing!, now),
                    ),
                  ),
                  DataCell(
                    _TrackButton(
                      // Track needs a GPS position to show.
                      onPressed: vehicle.lastPing == null ? null : () {},
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE1E7EA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              30,
              25,
              30,
              22,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Active Fleet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                if (_loading && _fleet != null)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loadDashboard,
                    icon: const Icon(Icons.refresh, color: Color(0xFF53636B)),
                  ),
              ],
            ),
          ),

          const Divider(
            height: 1,
            color: Color(0xFFE7EBED),
          ),

          body,
        ],
      ),
    );
  }

  String _routeLabel(String routeId) {
    final route = _routes[routeId];
    if (route != null) return route.label;
    return routeId.isEmpty ? '—' : 'Unlisted route';
  }

  static String _crowdLabel(String? level) {
    switch (level?.toLowerCase()) {
      case 'low':
        return 'Low';
      case 'medium':
        return 'Medium';
      case 'high':
        return 'High';
      default:
        return '—';
    }
  }

  Widget _vehicleStatus(FleetVehicle vehicle, DateTime now) {
    if (vehicle.suspended) {
      return const _StatusBadge(label: 'Suspended', tone: _BadgeTone.red);
    }
    if (vehicle.status == 'maintenance') {
      return const _StatusBadge(label: 'Maintenance', tone: _BadgeTone.amber);
    }
    if (vehicle.status != 'active') {
      return const _StatusBadge(label: 'Inactive', tone: _BadgeTone.grey);
    }
    if (vehicle.routeStatus == 'suspended') {
      return const _StatusBadge(label: 'Route Suspended', tone: _BadgeTone.red);
    }
    if (!vehicle.hasRecentPing(now)) {
      return const _StatusBadge(label: 'Offline', tone: _BadgeTone.grey);
    }
    if (vehicle.routeStatus == 'congested') {
      return const _StatusBadge(label: 'Delayed', tone: _BadgeTone.red);
    }
    return const _StatusBadge(label: 'On-Route', tone: _BadgeTone.green);
  }

  Widget _buildAnnouncementManagement() {
    final announcements = _announcements ?? const <Announcement>[];
    final now = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE1E7EA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              30,
              25,
              30,
              22,
            ),
            child: Text(
              'Announcement Management',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),

          const Divider(
            height: 1,
            color: Color(0xFFE7EBED),
          ),

          if (_loading && _announcements == null)
            const Padding(
              padding: EdgeInsets.all(26),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_announcementsError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 20, 30, 0),
              child: Text(
                _announcementsError!,
                style: const TextStyle(color: Color(0xFFE53935), fontSize: 15),
              ),
            )
          else if (announcements.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(30, 20, 30, 0),
              child: Text(
                'No active announcements.',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            )
          else
            for (final a in announcements)
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 18, 30, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.campaign_outlined,
                        color: primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            a.message,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF53636B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (a.createdAt != null)
                      Text(
                        timeAgo(a.createdAt!, now),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8A969D),
                        ),
                      ),
                  ],
                ),
              ),

          Padding(
            padding: const EdgeInsets.all(26),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 82,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFD9E0E4),
                      ),
                    ),
                    alignment: Alignment.topLeft,
                    child: const Text(
                      'Type announcement here...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF839099),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                SizedBox(
                  width: 64,
                  height: 82,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA9C8ED),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Icon(
                      Icons.send_outlined,
                      size: 27,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(
    String title,
    String description,
    IconData icon,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 64,
            color: primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  IconData _menuIcon(int index) {
    switch (index) {
      case 1:
        return Icons.directions_bus_outlined;
      case 2:
        return Icons.navigation_outlined;
      case 3:
        return Icons.notifications_none;
      case 4:
        return Icons.person_outline;
      case 5:
        return Icons.settings_outlined;
      default:
        return Icons.dashboard_outlined;
    }
  }
}

enum _BadgeTone { green, red, amber, grey }

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.tone,
  });

  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (tone) {
      _BadgeTone.green => (const Color(0xFFE4F4E9), const Color(0xFF26914D)),
      _BadgeTone.red => (const Color(0xFFFFEDEE), const Color(0xFFE53935)),
      _BadgeTone.amber => (const Color(0xFFFFF4DF), const Color(0xFFB77900)),
      _BadgeTone.grey => (const Color(0xFFF0F1F2), const Color(0xFF687077)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

class _TrackButton extends StatelessWidget {
  const _TrackButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF16869A),
        side: BorderSide(
          color: onPressed == null
              ? const Color(0xFFC5D0D5)
              : const Color(0xFF16869A),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 8,
        ),
        minimumSize: const Size(64, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: const Text('Track'),
    );
  }
}
