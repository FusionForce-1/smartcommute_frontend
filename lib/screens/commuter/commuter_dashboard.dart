// Commuter dashboard
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../models/commuter_profile.dart';
import '../../models/selected_trip.dart';
import '../../models/transport_model.dart';
import '../../models/transport_stop.dart';
import '../../models/trip_plan.dart';
import '../../models/vehicles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notices_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/trip_plan_provider.dart';
import '../../router/app_router.dart';
import '../../services/dio_interceptor.dart';
import '../../services/location_source.dart';
import '../../services/notices_service.dart';
import '../../services/profile_service.dart';
import '../../services/route_services.dart';
import '../../services/stops_services.dart';
import '../../services/trip_plan_service.dart';
import '../../services/vehicles_service.dart';
import '../../widgets/commuter/commuter_header.dart';
import '../../widgets/commuter/commuter_nav_bar.dart';
import '../../services/place_search.dart';
import 'home.dart';
import 'notifications_tab.dart';
import 'profile.dart';
import 'route.dart';

/// Commuter dashboard widget
class CommuterDashboard extends StatefulWidget {
  /// Create commuter dashboard
  const CommuterDashboard({super.key, this.isGuest = false});

  final bool isGuest;

  /// Create widget state
  @override
  State<CommuterDashboard> createState() => _CommuterDashboardState();
}

/// Commuter dashboard state
class _CommuterDashboardState extends State<CommuterDashboard> {
  static const _homeTab = 0;
  static const _routeTab = 1;
  static const _alertsTab = 2;
  static const _profileTab = 3;

  List<CommuterNavItem> get _navItems => [
        const CommuterNavItem(icon: AppIcons.navHome, label: 'Home'),
        const CommuterNavItem(icon: AppIcons.navRoute, label: 'Route'),
        CommuterNavItem(icon: AppIcons.navAlerts, label: 'Alerts', showDot: _notices.unreadCount > 0),
        const CommuterNavItem(icon: AppIcons.navProfile, label: 'Profile'),
      ];

  final Dio _dio = buildDioClient();

  late final TripPlanProvider _trip = TripPlanProvider(
    service: TripPlanService(_dio),
    locationSource: GeolocatorLocationSource(),
    isGuest: widget.isGuest,
  );
  late final NoticesProvider _notices =
      NoticesProvider(service: NoticesService(_dio), isGuest: widget.isGuest);
  late final AppLifecycleListener _lifecycle;
  late final ProfileProvider _profile =
      ProfileProvider(service: ProfileService(_dio), isGuest: widget.isGuest);

  int _currentIndex = 0;
  List<TransportStop> _stops = const [];
  List<TransportRoute> _routes = const [];
  List<Vehicle> _vehicles = const [];

  SelectedTrip? _selectedTrip;

  /// Initialize widget state
  @override
  void initState() {
    super.initState();
    PlaceIndex.landmarks();
    _loadFleet();
    _notices.load();
    _notices.startPolling();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _notices.checkForNew();
        _notices.startPolling();
      },
      onHide: _notices.stopPolling,
    );
    _profile.load();
  }

  /// Clean up resources
  @override
  void dispose() {
    _trip.dispose();
    _lifecycle.dispose();
    _notices.dispose();
    _profile.dispose();
    super.dispose();
  }

  /// Load fleet
  void _loadFleet() {
    _lastFleetLoad = DateTime.now();
    _load('stops', StopsService(_dio).getStops,
        (items) => _stops = [for (final s in items) if (s.routeIds.isNotEmpty) s]);
    _load('routes', RoutesService(_dio).getRoutes, (items) => _routes = items);
    _load('vehicles', VehiclesService(_dio).getVehicles, (items) => _vehicles = items);
  }

  DateTime _lastFleetLoad = DateTime.fromMillisecondsSinceEpoch(0);

  /// Reload fleet
  void _reloadFleet({bool force = false}) {
    if (!force && DateTime.now().difference(_lastFleetLoad) < const Duration(seconds: 30)) return;
    _loadFleet();
  }

  /// Load commuter dashboard
  Future<void> _load<T>(
    String what,
    Future<List<T>> Function() fetch,
    void Function(List<T>) apply,
  ) async {
    try {
      final items = await fetch();
      if (mounted) setState(() => apply(items));
    } catch (e) {
      debugPrint('Failed to load $what: $e');
    }
  }

  /// Sign out
  Future<void> _signOut({bool createAccount = false}) async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreenHost()),
      (route) => false,
    );
    if (createAccount) {
      navigator.push(MaterialPageRoute(builder: (_) => const RegisterScreenHost()));
    }
  }

  /// Select tab
  void _selectTab(int index) {
    if (index == _alertsTab && index != _currentIndex) _notices.checkForNew();
    setState(() => _currentIndex = index);
  }

  /// Open saved route
  void _openSavedRoute(SavedRoute route) {
    final origin = route.origin;
    final destination = route.destination;
    if (origin != null) _trip.setOrigin(origin, route.originName);
    if (destination != null) _trip.setDestination(destination, route.destinationName);
    setState(() => _currentIndex = _routeTab);
  }

  /// On trip started
  void _onTripStarted(RouteOption option, String from, String to) {
    _profile.recordTrip(option, from: from, to: to);
  }

  /// Select trip
  void _selectTrip(SelectedTrip trip) {
    final dashboard = ModalRoute.of(context);
    Navigator.of(context).popUntil((route) => route == dashboard);
    setState(() {
      _selectedTrip = trip;
      _currentIndex = _homeTab;
    });
  }

  /// Cancel trip
  void _cancelTrip() {
    final cancelled = _selectedTrip;
    if (cancelled == null) return;
    setState(() => _selectedTrip = null);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Selected route cleared.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (mounted && _selectedTrip == null) setState(() => _selectedTrip = cancelled);
          },
        ),
      ));
  }

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _trip),
        ChangeNotifierProvider.value(value: _notices),
        ChangeNotifierProvider.value(value: _profile),
      ],
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AppColors.backgroundIceBlue,
          body: Column(
            children: [
              if (_currentIndex != _profileTab) const CommuterHeader(),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    HomeTab(
                      stops: _stops,
                      routes: _routes,
                      vehicles: _vehicles,
                      onUnknownVehicle: () => _reloadFleet(),
                      onRefresh: () => _reloadFleet(force: true),
                      selectedTrip: _selectedTrip,
                      onCancelTrip: _cancelTrip,
                    ),
                    RouteTab(
                      stops: _stops,
                      routes: _routes,
                      onTripStarted: _onTripStarted,
                      onRouteSelected: _selectTrip,
                      loadVehicles: VehiclesService(_dio).getVehicles,
                    ),
                    NotificationsTab(onCreateAccount: () => _signOut(createAccount: true)),
                    ProfileTab(
                      isGuest: widget.isGuest,
                      stops: _stops,
                      routes: _routes,
                      vehicles: _vehicles,
                      onOpenSavedRoute: _openSavedRoute,
                      onSignOut: _signOut,
                      onCreateAccount: () => _signOut(createAccount: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: ListenableBuilder(
            listenable: _notices,
            builder: (context, _) => CommuterNavBar(
              items: _navItems,
              selectedIndex: _currentIndex,
              onSelected: _selectTab,
            ),
          ),
        ),
      ),
    );
  }
}
