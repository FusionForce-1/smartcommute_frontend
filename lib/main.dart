import 'package:flutter/material.dart';
import 'config/env_config.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loads .env and finds whichever backend address answers on this network.
  await EnvConfig.load();

  runApp(const SmartCommuteAuthApp());
}