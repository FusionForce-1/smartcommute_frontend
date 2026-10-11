import 'package:dio/dio.dart';
import '../models/vehicles.dart';

class VehiclesService {
  VehiclesService(this._dio);

  final Dio _dio;

  Future<List<Vehicle>> getVehicles() async {
    final response = await _dio.get('/vehicles');

    final data = response.data as List<dynamic>;

    return data
        .map(
          (item) => Vehicle.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}