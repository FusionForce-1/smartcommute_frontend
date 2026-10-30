// lib/screens/driver/driver_dashboard.dart
//
// Driver dashboard shell: owns the driver's state (shift, backup phone GPS,
// live feed) for as long as the dashboard is open, checks for shift
// changes from the operator, and handles sign-out. The screen itself is
// DriverDashboardView (Map, Updates and Profile tabs).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/driver_provider.dart';
import '../../router/app_router.dart';
import '../../services/dio_interceptor.dart';
import '../../services/driver_service.dart';
import '../../services/profile_service.dart';
import '../../services/websocket_service.dart';
import 'driver_dashboard_view.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final Dio _dio = buildDioClient();

  late final DriverProvider _driver = DriverProvider(
    DriverService(_dio),
    liveFeed: WebSocketService(),
  );

  /// Privacy & Security on the Profile tab (/users/me/*).
  late final ProfileService _profileService = ProfileService(_dio);

  @override
  void initState() {
    super.initState();
    _driver.load();
    _driver.startAutoRefresh();
  }

  @override
  void dispose() {
    _driver.dispose(); // also stops the phone's GPS
    super.dispose();
  }

  Future<void> _signOut() async {
    await _driver.gps.stop();
    if (!mounted) return;
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreenHost()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _driver,
      child: DriverDashboardView(onSignOut: _signOut, profileService: _profileService),
    );
  }
}
