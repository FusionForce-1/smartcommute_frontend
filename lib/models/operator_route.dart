// Operator route management models — mirror GET /routes/mine and
// POST /routes on the backend.

/// One card on the operator's Route Management page.
class OperatorRoute {
  const OperatorRoute({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
    required this.owned,
    this.origin,
    this.destination,
    this.baseFare,
    this.stopCount = 0,
    this.vehicleCount = 0,
  });

  final String id;
  final String code;
  final String name;
  final String? origin; // terminal_a
  final String? destination; // terminal_b
  final double? baseFare;
  final int stopCount;
  final int vehicleCount; // this operator's vehicles on the route
  final bool isActive;

  /// False for routes the operator only runs vehicles on: they can't pause,
  /// activate or delete those.
  final bool owned;

  factory OperatorRoute.fromJson(Map<String, dynamic> json) => OperatorRoute(
        id: json['id'] as String,
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        origin: json['terminal_a'] as String?,
        destination: json['terminal_b'] as String?,
        baseFare: (json['base_fare'] as num?)?.toDouble(),
        stopCount: json['stop_count'] as int? ?? 0,
        vehicleCount: json['vehicle_count'] as int? ?? 0,
        isActive: json['is_active'] as bool? ?? false,
        owned: json['owned'] as bool? ?? false,
      );

  OperatorRoute copyWith({bool? isActive}) => OperatorRoute(
        id: id,
        code: code,
        name: name,
        origin: origin,
        destination: destination,
        baseFare: baseFare,
        stopCount: stopCount,
        vehicleCount: vehicleCount,
        isActive: isActive ?? this.isActive,
        owned: owned,
      );

  /// "₱18", "₱12.50", or "—" when no fare is set.
  String get fareLabel {
    final fare = baseFare;
    if (fare == null) return '—';
    return fare == fare.roundToDouble()
        ? '₱${fare.toInt()}'
        : '₱${fare.toStringAsFixed(2)}';
  }
}

/// The fields of the Create New Route form.
class NewRoute {
  const NewRoute({
    required this.code,
    required this.name,
    required this.origin,
    required this.destination,
    required this.baseFare,
  });

  final String code;
  final String name;
  final String origin;
  final String destination;
  final double baseFare;

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'terminal_a': origin,
        'terminal_b': destination,
        'fare_matrix': {'base': baseFare},
      };
}
