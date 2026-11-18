// Env config
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Env config
class EnvConfig {
  /// Create env config
  EnvConfig._();

  static String? _resolvedApiBaseUrl;

  /// Load env config
  static Future<void> load() async {
    await dotenv.load(fileName: ".env");
    await resolveBackend();
  }

  static const Duration _lanProbeTimeout = Duration(seconds: 3);

  static const Duration _cloudProbeTimeout = Duration(seconds: 60);

  /// Resolve backend
  static Future<void> resolveBackend() async {
    final candidates = (dotenv.env['API_BASE_URLS'] ?? '')
        .split(',')
        .map((u) => u.trim().replaceAll(RegExp(r'/+$'), ''))
        .where((u) => u.isNotEmpty)
        .toList();
    if (candidates.isEmpty) return;

    final probes = <Dio>[];
    final answers = [
      for (final url in candidates)
        () async {
          final timeout = url.startsWith('https://') ? _cloudProbeTimeout : _lanProbeTimeout;
          final dio = Dio(BaseOptions(connectTimeout: timeout, receiveTimeout: timeout));
          probes.add(dio);
          try {
            final res = await dio.get('$url/health');
            return res.statusCode == 200;
          } catch (_) {
            return false;
          }
        }(),
    ];

    String? picked;
    for (var i = 0; i < candidates.length; i++) {
      if (await answers[i]) {
        picked = candidates[i];
        break;
      }
    }
    for (final dio in probes) {
      dio.close(force: true);
    }

    _resolvedApiBaseUrl = picked;
    debugPrint(picked != null
        ? '[Env] Backend found at $picked'
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
    final resolved = _resolvedApiBaseUrl;
    if (resolved != null) return resolved.replaceFirst(RegExp(r'^http'), 'ws');
    final url = _platformUrl('WS_BASE_URL');
    if (url == null) {
      throw Exception('WS_BASE_URL is missing from .env');
    }
    return url;
  }

  /// Platform URL
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

  static String? get googleMapsApiKey {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty) return null;
    return key;
  }

  static String? get googleWebClientId {
    final id = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    if (id == null || id.isEmpty) return null;
    return id;
  }

  static bool get debugLogging {
    return dotenv.env['DEBUG_LOGGING']?.toLowerCase() == 'true';
  }
}