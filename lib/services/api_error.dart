// lib/services/api_error.dart
//
// Turns a failed API call into a sentence the commuter can read.

import 'package:dio/dio.dart';

const String genericErrorMessage = 'Something went wrong. Please try again.';

String apiErrorMessage(Object error) {
  if (error is! DioException) return genericErrorMessage;

  // FastAPI puts a readable reason in "detail" (a list for validation errors).
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
