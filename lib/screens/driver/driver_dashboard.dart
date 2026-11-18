// Driver dashboard
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

/// Driver dashboard widget
class DriverDashboard extends StatefulWidget {
  /// Create driver dashboard
  const DriverDashboard({super.key});

  /// Create widget state
  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

/// Driver dashboard state
class _DriverDashboardState extends State<DriverDashboard> {
  final Dio _dio = buildDioClient();

  late final DriverProvider _driver = DriverProvider(
    DriverService(_dio),
    liveFeed: WebSocketService(),
  );

  late final ProfileService _profileService = ProfileService(_dio);

  /// Initialize widget state
  @override
  void initState() {
    super.initState();
    _driver.load();
    _driver.startAutoRefresh();
  }

  /// Clean up resources
  @override
  void dispose() {
    _driver.dispose();
    super.dispose();
  }

  /// Sign out
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

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _driver,
      child: DriverDashboardView(onSignOut: _signOut, profileService: _profileService),
    );
  }
}
