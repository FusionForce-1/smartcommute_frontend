// lib/screens/commuter/commuter_dashboard.dart
//
// Commuter dashboard shell: logo header, the four tabs (Home, Route,
// Alerts, Profile) and the bottom navigation. Loads stops, routes and
// vehicles once and hands them to the tabs that need them, and owns the
// trip, alert and profile state so it survives switching tabs.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../models/commuter_profile.dart';
import '../../models/transport_model.dart';
import '../../models/transport_stop.dart';
import '../../models/trip_plan.dart';
import '../../models/vehicles.dart';
import '../../providers/alerts_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/trip_plan_provider.dart';
import '../../router/app_router.dart';
import '../../services/alerts_service.dart';
import '../../services/dio_interceptor.dart';
import '../../services/location_source.dart';
import '../../services/profile_service.dart';
import '../../services/route_services.dart';
import '../../services/stops_services.dart';
import '../../services/trip_plan_service.dart';
import '../../services/vehicles_service.dart';
import '../../widgets/commuter/commuter_header.dart';
import '../../widgets/commuter/commuter_nav_bar.dart';
import 'alert.dart';
import '../../services/place_search.dart';
import 'home.dart';
import 'profile.dart';
import 'route.dart';

class CommuterDashboard extends StatefulWidget {
  const CommuterDashboard({super.key, this.isGuest = false});

  /// True when opened via "Continue as Guest" — no profile, and alerts
  /// come from the public list without read state.
  final bool isGuest;

  @override
  State<CommuterDashboard> createState() => _CommuterDashboardState();
}

class _CommuterDashboardState extends State<CommuterDashboard> {
  static const _navItems = [
    CommuterNavItem(icon: AppIcons.navHome, label: 'Home'),
    CommuterNavItem(icon: AppIcons.navRoute, label: 'Route'),
    CommuterNavItem(icon: AppIcons.navAlerts, label: 'Alerts'),
    CommuterNavItem(icon: AppIcons.navProfile, label: 'Profile'),
  ];
  static const _routeTab = 1;
  static const _profileTab = 3;

  // Signs requests with the commuter's token (and refreshes it);
  // /trip-plan, /alerts/feed and /users/me reject anonymous calls.
  final Dio _dio = buildDioClient();

  late final TripPlanProvider _trip = TripPlanProvider(
    service: TripPlanService(_dio),
    locationSource: GeolocatorLocationSource(),
  );
  late final AlertsProvider _alerts =
      AlertsProvider(service: AlertsService(_dio), isGuest: widget.isGuest);
  late final ProfileProvider _profile =
      ProfileProvider(service: ProfileService(_dio), isGuest: widget.isGuest);

  int _currentIndex = 0;
  List<TransportStop> _stops = const [];
  List<TransportRoute> _routes = const [];
  List<Vehicle> _vehicles = const [];

  @override
  void initState() {
    super.initState();
    // Metro Cebu landmarks for From / To search: load now so it's instant later.
    PlaceIndex.landmarks();
    _loadFleet();
    _alerts.load();
    _profile.load();
  }

  @override
  void dispose() {
    _trip.dispose();
    _alerts.dispose();
    _profile.dispose();
    super.dispose();
  }

  /// Stops, routes and vehicles. Each list loads on its own, so one failing
  /// doesn't hide the others. Only stops a route serves: a stop no jeepney
  /// uses can't be boarded, so it would just clutter the map and search.
  void _loadFleet() {
    _lastFleetLoad = DateTime.now();
    _load('stops', StopsService(_dio).getStops,
        (items) => _stops = [for (final s in items) if (s.routeIds.isNotEmpty) s]);
    _load('routes', RoutesService(_dio).getRoutes, (items) => _routes = items);
    _load('vehicles', VehiclesService(_dio).getVehicles, (items) => _vehicles = items);
  }

  DateTime _lastFleetLoad = DateTime.fromMillisecondsSinceEpoch(0);

  /// The lists are loaded once at start, so a jeep or route an operator adds
  /// (or activates) while the app is open was unknown and left out of Nearby
  /// Vehicles. Home calls this when a live jeep doesn't match the lists; at
  /// most every 30 s unless [force] (the Refresh button).
  void _reloadFleet({bool force = false}) {
    if (!force && DateTime.now().difference(_lastFleetLoad) < const Duration(seconds: 30)) return;
    _loadFleet();
  }

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

  /// Ends the session (or guest visit) and returns to Login — opening
  /// Register on top of it when [createAccount] is set.
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

  /// Fills From / To on the Route tab with a saved route, then shows it.
  void _openSavedRoute(SavedRoute route) {
    final origin = route.origin;
    final destination = route.destination;
    if (origin != null) _trip.setOrigin(origin, route.originName);
    if (destination != null) _trip.setDestination(destination, route.destinationName);
    setState(() => _currentIndex = _routeTab);
  }

  void _onTripStarted(RouteOption option, String from, String to) {
    _profile.recordTrip(option, from: from, to: to);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _trip),
        ChangeNotifierProvider.value(value: _alerts),
        ChangeNotifierProvider.value(value: _profile),
      ],
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark, // dark status-bar icons on the sky header
        child: Scaffold(
          backgroundColor: AppColors.backgroundIceBlue,
          body: Column(
            children: [
              // The Profile tab has its own teal header.
              if (_currentIndex != _profileTab) const CommuterHeader(),
              Expanded(
                // IndexedStack keeps every tab alive, so the Home tab's live
                // vehicle socket stays open while browsing other tabs.
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    HomeTab(
                      stops: _stops,
                      routes: _routes,
                      vehicles: _vehicles,
                      onUnknownVehicle: () => _reloadFleet(),
                      onRefresh: () => _reloadFleet(force: true),
                    ),
                    RouteTab(stops: _stops, routes: _routes, onTripStarted: _onTripStarted),
                    const AlertsTab(),
                    ProfileTab(
                      isGuest: widget.isGuest,
                      stops: _stops,
                      routes: _routes,
                      onOpenSavedRoute: _openSavedRoute,
                      onSignOut: _signOut,
                      onCreateAccount: () => _signOut(createAccount: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: CommuterNavBar(
            items: _navItems,
            selectedIndex: _currentIndex,
            onSelected: (index) => setState(() => _currentIndex = index),
          ),
        ),
      ),
    );
  }
}
