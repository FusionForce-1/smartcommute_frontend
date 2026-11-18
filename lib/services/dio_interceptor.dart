// Dio interceptor
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env_config.dart';

/// Dio interceptor
class DioInterceptor extends Interceptor {
  final Dio dio;
  final FlutterSecureStorage secureStorage;

  bool _isRefreshing = false;

  /// Create dio interceptor
  DioInterceptor({required this.dio, required this.secureStorage});

  /// On request
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await secureStorage.read(key: 'access_token');

    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    if (EnvConfig.debugLogging) {
      // ignore: avoid_print
      print('[API] ${options.method} ${options.path}');
    }

    handler.next(options);
  }

  /// On response
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (EnvConfig.debugLogging) {
      // ignore: avoid_print
      print('[API] ${response.requestOptions.path} -> ${response.statusCode}');
    }
    handler.next(response);
  }

  /// On error
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;

    if (statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await secureStorage.read(key: 'refresh_token');

        if (refreshToken == null) {
          _isRefreshing = false;
          return handler.next(err);
        }

        final refreshDio = Dio(BaseOptions(baseUrl: EnvConfig.apiBaseUrl));
        final response = await refreshDio.post(
          '/auth/refresh',
          data: {'refresh_token': refreshToken},
        );

        final newAccessToken = response.data['access_token'];
        final newRefreshToken = response.data['refresh_token'];

        await secureStorage.write(key: 'access_token', value: newAccessToken);
        await secureStorage.write(key: 'refresh_token', value: newRefreshToken);

        err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
        final retryResponse = await dio.fetch(err.requestOptions);

        _isRefreshing = false;
        return handler.resolve(retryResponse);

      } catch (refreshError) {
        _isRefreshing = false;
        await secureStorage.deleteAll();
        return handler.next(err);
      }
    }

    if (statusCode == 403) {
      return handler.next(err);
    }

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.connectionError) {
      if (EnvConfig.debugLogging) {
        // ignore: avoid_print
        print('[API] Network error: ${err.message}');
      }
    }

    handler.next(err);
  }
}

/// Build dio client
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