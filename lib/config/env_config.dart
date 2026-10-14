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

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // Private constructor — this class is never instantiated,
  // it's just a namespace for static values.
  EnvConfig._();

  /// The backend picked by [resolveBackend], or null to use API_BASE_URL.
  static String? _resolvedApiBaseUrl;

  static Future<void> load() async {
    await dotenv.load(fileName: ".env");
    await resolveBackend();
  }

  /// The laptop running the backend has a different IP on every network
  /// (home Wi-Fi, phone hotspot...). API_BASE_URLS lists them all,
  /// comma-separated; each is asked for /health at the same time and the
  /// first one in the list that answers is used. Falls back to API_BASE_URL.
  static Future<void> resolveBackend() async {
    final candidates = (dotenv.env['API_BASE_URLS'] ?? '')
        .split(',')
        .map((u) => u.trim().replaceAll(RegExp(r'/+$'), ''))
        .where((u) => u.isNotEmpty)
        .toList();
    if (candidates.isEmpty) return;

    final probe = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
    ));
    final reachable = await Future.wait(candidates.map((url) async {
      try {
        final res = await probe.get('$url/health');
        return res.statusCode == 200;
      } catch (_) {
        return false;
      }
    }));
    probe.close();

    final i = reachable.indexOf(true);
    _resolvedApiBaseUrl = i >= 0 ? candidates[i] : null;
    debugPrint(i >= 0
        ? '[Env] Backend found at ${candidates[i]}'
        : '[Env] No backend answered from $candidates — using API_BASE_URL');
  }

  static String get apiBaseUrl {
    final resolved = _resolvedApiBaseUrl;
    if (resolved != null) return resolved;
    final url = _platformUrl('API_BASE_URL');
    if (url == null) {
      throw Exception(
        'API_BASE_URL is missing from .env — did you call EnvConfig.load() in main.dart?',
      );
    }
    return url;
  }

  static String get wsBaseUrl {
    // Same host as the resolved API: http -> ws, https -> wss.
    final resolved = _resolvedApiBaseUrl;
    if (resolved != null) return resolved.replaceFirst(RegExp(r'^http'), 'ws');
    final url = _platformUrl('WS_BASE_URL');
    if (url == null) {
      throw Exception('WS_BASE_URL is missing from .env');
    }
    return url;
  }

  /// On Android, `localhost` is the phone itself, not the dev PC.
  /// An explicit `<KEY>_ANDROID` entry wins (use your PC's LAN IP for a
  /// real phone); otherwise localhost is rewritten to 10.0.2.2, which the
  /// Android emulator maps to the host machine.
  static String? _platformUrl(String key) {
    String? read(String k) {
      final v = dotenv.env[k];
      return (v == null || v.isEmpty) ? null : v;
    }

    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) return read(key);

    final override = read('${key}_ANDROID');
    if (override != null) return override;

    final url = read(key);
    if (url == null) return null;
    final uri = Uri.parse(url);
    if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
      return uri.replace(host: '10.0.2.2').toString();
    }
    return url;
  }

  /// Optional — enables Street View photos for stops. Returns null if unset,
  /// in which case stops use the free satellite snapshot instead.
  static String? get googleMapsApiKey {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty) return null;
    return key;
  }

  /// The Google OAuth *Web* client ID (same one the backend verifies).
  /// Android needs it as serverClientId to get an ID token; web reads its
  /// own copy from web/index.html. Not a secret.
  static String? get googleWebClientId {
    final id = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    if (id == null || id.isEmpty) return null;
    return id;
  }

  static bool get debugLogging {
    return dotenv.env['DEBUG_LOGGING']?.toLowerCase() == 'true';
  }
}