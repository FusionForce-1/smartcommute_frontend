class Vehicle {
  const Vehicle({
    required this.id,
    required this.plateNumber,
    required this.routeId,
    required this.status,
    this.crowdLevel,
    this.lastPosition,
  });

  final String id;
  final String plateNumber;
  final String routeId;
  final String status;
  final String? crowdLevel;
  final Map<String, dynamic>? lastPosition;

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      plateNumber: json['plate_number'] as String,
      routeId: json['route_id'] as String,
      status: json['status'] as String? ?? 'active',
      crowdLevel: json['crowd_level'] as String?,
      lastPosition:
          json['last_position'] as Map<String, dynamic>?,
    );
  }
}