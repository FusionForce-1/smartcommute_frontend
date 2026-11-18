// API error
import 'package:dio/dio.dart';

const String genericErrorMessage = 'Something went wrong. Please try again.';

/// API error message
String apiErrorMessage(Object error) {
  if (error is! DioException) return genericErrorMessage;

  final data = error.response?.data;
  if (data is Map && data['detail'] is String) return data['detail'] as String;

  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return "Can't reach the server. Check your connection.";
    default:
      return genericErrorMessage;
  }
}
