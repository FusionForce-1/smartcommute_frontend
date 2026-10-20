import 'package:flutter/material.dart';
import 'config/env_config.dart';
import 'router/app_router.dart';
import 'screens/loading_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // The loading screen shows while .env loads and the app finds whichever
  // backend address answers on this network.
  runApp(AppLoader(
    load: EnvConfig.load,
    builder: (_) => const SmartCommuteAuthApp(),
  ));
}
