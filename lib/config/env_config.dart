// lib/config/env_config.dart
//
// Wraps flutter_dotenv so the rest of the app never touches
// dotenv directly — it just calls EnvConfig.apiBaseUrl etc.
// This means if you ever swap HOW config is loaded (e.g. to
// --dart-define flags for a release build), you only edit THIS file.
//
// Setup required (one-time):
//   1. Add to pubspec.yaml:
//        dependencies:
//          flutter_dotenv: ^5.x
//        flutter:
//          assets:
//            - .env
//   2. Run: flutter pub get
//   3. Call EnvConfig.load() once, in main.dart, BEFORE runApp()

import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // Private constructor — this class is never instantiated,
  // it's just a namespace for static values.
  EnvConfig._();

  static Future<void> load() async {
    await dotenv.load(fileName: ".env");
  }

  static String get apiBaseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception(
        'API_BASE_URL is missing from .env — did you call EnvConfig.load() in main.dart?',
      );
    }
    return url;
  }

  static String get wsBaseUrl {
    final url = dotenv.env['WS_BASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception('WS_BASE_URL is missing from .env');
    }
    return url;
  }

  static bool get debugLogging {
    return dotenv.env['DEBUG_LOGGING']?.toLowerCase() == 'true';
  }
}