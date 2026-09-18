import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // MUST happen before ApiService/AuthProvider are ever constructed —
  // anything that reads EnvConfig.apiBaseUrl (which ApiService does,
  // via buildDioClient()) will throw flutter_dotenv's own
  // NotInitializedError if .env hasn't been loaded yet. This was
  // missing in the previous version of this file — that's what
  // caused the red screen on app launch.
  await EnvConfig.load();

  await dotenv.load(fileName: ".env");

  runApp(const SmartCommuteAuthApp());
}