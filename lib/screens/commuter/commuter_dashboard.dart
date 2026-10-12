// lib/screens/commuter/commuter_dashboard.dart
//
// Commuter dashboard shell: logo header, the four tabs (Home, Route,
// Alerts, Profile) and the bottom navigation. Loads stops, routes and
// vehicles once and hands them to the tabs that need them.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/env_config.dart';
import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../models/transport_model.dart';
import '../../models/transport_stop.dart';
import '../../models/vehicles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_plan_provider.dart';
import '../../router/app_router.dart';
import '../../services/location_source.dart';
import '../../services/route_services.dart';
import '../../services/stops_services.dart';
import '../../services/trip_plan_service.dart';
import '../../services/vehicles_service.dart';
import '../../widgets/commuter/commuter_header.dart';
import '../../widgets/commuter/commuter_nav_bar.dart';
import 'alert.dart';
import 'home.dart';
import 'profile.dart';
import 'route.dart';

class CommuterDashboard extends StatefulWidget {
  const CommuterDashboard({super.key, this.isGuest = false});

  /// True when opened via "Continue as Guest" — profile actions stay disabled.
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

  final Dio _dio = Dio(BaseOptions(baseUrl: EnvConfig.apiBaseUrl));

  int _currentIndex = 0;
  List<TransportStop> _stops = const [];
  List<TransportRoute> _routes = const [];
  List<Vehicle> _vehicles = const [];

  @override
  void initState() {
    super.initState();
    // Each list loads on its own, so one failing doesn't hide the others.
    _load('stops', StopsService(_dio).getStops, (items) => _stops = items);
    _load('routes', RoutesService(_dio).getRoutes, (items) => _routes = items);
    _load('vehicles', VehiclesService(_dio).getVehicles, (items) => _vehicles = items);
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreenHost()),
      (route) => false,
    );
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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // Lives with the dashboard so a planned trip survives closing the planner.
      create: (_) => TripPlanProvider(
        service: TripPlanService(_dio),
        locationSource: GeolocatorLocationSource(),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark, // dark status-bar icons on the sky header
        child: Scaffold(
          backgroundColor: AppColors.backgroundIceBlue,
          body: Column(
            children: [
              const CommuterHeader(),
              Expanded(
                // IndexedStack keeps every tab alive, so the Home tab's live
                // vehicle socket stays open while browsing other tabs.
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    HomeTab(stops: _stops, routes: _routes, vehicles: _vehicles),
                    RouteTab(stops: _stops, routes: _routes),
                    const AlertsTab(),
                    ProfileTab(isGuest: widget.isGuest, onSignOut: _signOut),
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
