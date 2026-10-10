// lib/services/dio_interceptor.dart
//
// WHAT THIS FILE DOES (read this before the code):
//
// Dio is the HTTP client package. On its own, it just sends requests.
// An "Interceptor" is a class you plug into Dio that gets a chance to
// look at (and modify) EVERY request before it's sent, and EVERY
// response/error before your code sees it. That's why we build this
// BEFORE ApiService — ApiService will just call `dio.get(...)` /
// `dio.post(...)`, and this interceptor handles auth transparently
// underneath, so none of the 19 ApiService methods need to manually
// attach tokens or handle expiry themselves.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env_config.dart';

class DioInterceptor extends Interceptor {
  final Dio dio;
  final FlutterSecureStorage secureStorage;

  // We track whether a token refresh is already in-flight so that if
  // 5 requests fail with 401 at the same moment (common when a screen
  // fires several API calls at once), we don't try to refresh 5 times
  // in parallel. Only the first triggers a refresh; the rest wait for it.
  bool _isRefreshing = false;

  DioInterceptor({required this.dio, required this.secureStorage});

  // ---------------------------------------------------------------
  // HOOK 1: onRequest — runs before every single request is sent
  // ---------------------------------------------------------------
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await secureStorage.read(key: 'access_token');

    // Guest sessions have no access_token in storage at all —
    // continueAsGuest() never wrote one. So this correctly sends
    // NO Authorization header for guests, which is exactly what
    // the backend's get_optional_user() expects: it treats a
    // missing header as "anonymous", not as "invalid".
    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    if (EnvConfig.debugLogging) {
      // ignore: avoid_print
      print('[API] ${options.method} ${options.path}');
    }

    handler.next(options); // let the request continue on its way
  }

  // ---------------------------------------------------------------
  // HOOK 2: onResponse — runs after every successful (2xx) response
  // ---------------------------------------------------------------
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (EnvConfig.debugLogging) {
      // ignore: avoid_print
      print('[API] ${response.requestOptions.path} -> ${response.statusCode}');
    }
    handler.next(response);
  }

  // ---------------------------------------------------------------
  // HOOK 3: onError — runs when a request fails (network error, or
  // any non-2xx status code like 401/403/500)
  // ---------------------------------------------------------------
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;

    // --- 401: access token expired. Try to silently refresh it. ---
    if (statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await secureStorage.read(key: 'refresh_token');

        if (refreshToken == null) {
          // No refresh token means this was a guest request that
          // somehow got a 401, or the session was already fully
          // logged out. Nothing to refresh — bubble the error up.
          _isRefreshing = false;
          return handler.next(err);
        }

        // NOTE: use a fresh Dio instance for this call, NOT the
        // intercepted `dio` — otherwise this refresh request would
        // trigger this same onRequest hook, try to attach the (now
        // expired) access_token, and potentially loop.
        final refreshDio = Dio(BaseOptions(baseUrl: EnvConfig.apiBaseUrl));
        final response = await refreshDio.post(
          '/auth/refresh',
          data: {'refresh_token': refreshToken},
        );

        final newAccessToken = response.data['access_token'];
        final newRefreshToken = response.data['refresh_token'];

        await secureStorage.write(key: 'access_token', value: newAccessToken);
        await secureStorage.write(key: 'refresh_token', value: newRefreshToken);

        // Retry the ORIGINAL failed request, now with the new token.
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
        final retryResponse = await dio.fetch(err.requestOptions);

        _isRefreshing = false;
        return handler.resolve(retryResponse); // caller sees a normal success

      } catch (refreshError) {
        _isRefreshing = false;
        // Refresh itself failed (refresh token also expired/invalid).
        // Clear everything — this is a real "please log in again" moment.
        await secureStorage.deleteAll();
        // AuthProvider should be listening for this via a stream/callback
        // to navigate to /login with "Session expired". We cover wiring
        // that up when we build AuthProvider next.
        return handler.next(err);
      }
    }

    // --- 403: user is authenticated but not allowed to do this. ---
    if (statusCode == 403) {
      // Unlike 401, this is NOT about an expired token — refreshing
      // won't help. The user's role genuinely lacks permission.
      // We just let it propagate; AuthProvider/UI decides how to show it.
      return handler.next(err);
    }

    // --- Network errors (timeout, no internet, DNS failure, etc.) ---
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.connectionError) {
      if (EnvConfig.debugLogging) {
        // ignore: avoid_print
        print('[API] Network error: ${err.message}');
      }
      // ErrorBanner widget shown by whichever screen catches this —
      // this file only classifies the error, the UI layer displays it.
    }

    handler.next(err);
  }
}

// ---------------------------------------------------------------
// Factory function: builds a fully-configured Dio instance.
// ApiService will call this once and reuse the same instance.
// ---------------------------------------------------------------
Dio buildDioClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: EnvConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  const secureStorage = FlutterSecureStorage();
  dio.interceptors.add(DioInterceptor(dio: dio, secureStorage: secureStorage));

  return dio;
}