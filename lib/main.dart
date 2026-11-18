// App entry point
import 'package:flutter/material.dart';
import 'config/env_config.dart';
import 'router/app_router.dart';
import 'screens/loading_screen.dart';

/// App entry point
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(AppLoader(
    load: EnvConfig.load,
    builder: (_) => const SmartCommuteAuthApp(),
  ));
}
