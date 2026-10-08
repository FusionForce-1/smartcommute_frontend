import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/driver.dart';

/// A license photo picked by the operator.
class LicenseImage {
  const LicenseImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  /// The backend only accepts image/png and image/jpeg uploads.
  DioMediaType get mediaType => name.toLowerCase().endsWith('.png')
      ? DioMediaType('image', 'png')
      : DioMediaType('image', 'jpeg');
}

class DriversService {
  DriversService(this._dio);

  final Dio _dio;

  Future<List<Driver>> getDrivers() async {
    final response = await _dio.get('/drivers');
    final data = response.data as List<dynamic>;
    return data
        .map((item) => Driver.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<LicenseScan> scanLicense({
    required LicenseImage front,
    required LicenseImage back,
  }) async {
    final form = FormData.fromMap({
      'front': MultipartFile.fromBytes(
        front.bytes,
        filename: front.name,
        contentType: front.mediaType,
      ),
      'back': MultipartFile.fromBytes(
        back.bytes,
        filename: back.name,
        contentType: back.mediaType,
      ),
    });
    final response = await _dio.post(
      '/drivers/scan-license',
      data: form,
      // OCR on two photos takes longer than a normal request.
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    );
    return LicenseScan.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DriverCreated> addDriver(Map<String, dynamic> body) async {
    final response = await _dio.post('/drivers', data: body);
    return DriverCreated.fromJson(response.data as Map<String, dynamic>);
  }

  /// Replaces the driver's login password. Returns the account email.
  Future<String?> updatePassword(String driverId, String password) async {
    final response = await _dio.patch(
      '/drivers/$driverId/account',
      data: {'password': password},
    );
    return (response.data as Map<String, dynamic>)['email'] as String?;
  }

  Future<void> deleteDriver(String driverId) async {
    await _dio.delete('/drivers/$driverId');
  }

  /// The operator's company name, shown in the page header.
  Future<String?> getCompanyName() async {
    final response = await _dio.get('/operators/me');
    return (response.data as Map<String, dynamic>)['company_name'] as String?;
  }
}

/// Readable message for a failed request, preferring the backend's `detail`.
String driverErrorMessage(Object error, String fallback) {
  if (error is DioException) {
    final response = error.response;
    if (response == null) {
      return "Can't reach the server. Check that the backend is running.";
    }
    final data = response.data;
    final detail = data is Map ? data['detail'] : null;
    if (detail is String && detail.isNotEmpty) return detail;
    // FastAPI validation errors: [{"msg": "...", ...}]
    if (detail is List && detail.isNotEmpty && detail.first is Map) {
      final msg = (detail.first as Map)['msg'];
      if (msg is String) return msg.replaceFirst('Value error, ', '');
    }
    if (response.statusCode == 403) return 'You are not allowed to do this.';
  }
  return fallback;
}
