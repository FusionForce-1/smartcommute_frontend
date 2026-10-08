// Driver roster models — mirror the backend's /drivers schemas
// (app/models/driver_models.py).

DateTime? _parseDate(Object? value) =>
    value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// Name particles that stay lowercase in "Juan dela Cruz".
const _nameParticles = {'de', 'del', 'dela', 'delos', 'los', 'la', 'van', 'von', 'y'};

/// "DELA CRUZ" -> "dela Cruz", "JUAN" -> "Juan".
String _titleCase(String value, {bool keepParticles = false}) {
  final words = value.trim().toLowerCase().split(RegExp(r'\s+'));
  return [
    for (var i = 0; i < words.length; i++)
      if (words[i].isEmpty)
        ''
      else if (keepParticles && i < words.length - 1 && _nameParticles.contains(words[i]))
        words[i]
      else
        words[i][0].toUpperCase() + words[i].substring(1),
  ].join(' ');
}

class Driver {
  const Driver({
    required this.id,
    required this.driverCode,
    required this.fullName,
    required this.firstName,
    required this.lastName,
    this.middleName,
    required this.licenseNumber,
    required this.expirationDate,
    required this.status,
    this.email,
    this.nationality,
    this.sex,
    this.dateOfBirth,
    this.weightKg,
    this.heightM,
    this.bloodType,
    this.agencyCode,
    this.eyesColor,
    this.dlCodes = const [],
    this.conditions,
    this.address,
    this.serialNumber,
    this.createdAt,
  });

  final String id;
  final String driverCode; // DRV-001
  final String fullName; // LAST, FIRST MIDDLE — as printed on the license
  final String firstName;
  final String lastName;
  final String? middleName;
  final String licenseNumber;
  final DateTime expirationDate;
  final String status; // active | off_duty

  /// Login email of the driver's account, when the backend sends one.
  final String? email;

  // Remaining fields read from the license.
  final String? nationality;
  final String? sex; // M | F
  final DateTime? dateOfBirth;
  final double? weightKg;
  final double? heightM;
  final String? bloodType;
  final String? agencyCode;
  final String? eyesColor;
  final List<String> dlCodes;
  final String? conditions;
  final String? address;
  final String? serialNumber;
  final DateTime? createdAt;

  factory Driver.fromJson(Map<String, dynamic> json) {
    final account = json['account'];
    return Driver(
      nationality: json['nationality'] as String?,
      sex: json['sex'] as String?,
      dateOfBirth: _parseDate(json['date_of_birth']),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      heightM: (json['height_m'] as num?)?.toDouble(),
      bloodType: json['blood_type'] as String?,
      agencyCode: json['agency_code'] as String?,
      eyesColor: json['eyes_color'] as String?,
      dlCodes: [for (final c in json['dl_codes'] as List? ?? const []) c.toString()],
      conditions: json['conditions'] as String?,
      address: json['address'] as String?,
      serialNumber: json['serial_number'] as String?,
      createdAt: _parseDate(json['created_at'])?.toLocal(),
      id: json['id'] as String,
      driverCode: json['driver_code'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      middleName: json['middle_name'] as String?,
      licenseNumber: json['license_number'] as String? ?? '',
      expirationDate: _parseDate(json['expiration_date']) ?? DateTime(1970),
      status: json['status'] as String? ?? 'off_duty',
      email: json['email'] as String? ??
          (account is Map ? account['email'] as String? : null),
    );
  }

  /// "Juan dela Cruz" — first name then last name, as shown in the roster.
  String get displayName {
    final name = '${_titleCase(firstName)} ${_titleCase(lastName, keepParticles: true)}'.trim();
    return name.isEmpty ? fullName : name;
  }

  bool get isActive => status.toLowerCase() == 'active';

  bool isLicenseExpired([DateTime? today]) {
    final now = today ?? DateTime.now();
    return expirationDate.isBefore(DateTime(now.year, now.month, now.day));
  }

}

/// Login generated for a new driver. [password] is only ever returned
/// once, in the response to POST /drivers.
class DriverAccountCredentials {
  const DriverAccountCredentials({required this.email, required this.password});

  final String email;
  final String password;

  factory DriverAccountCredentials.fromJson(Map<String, dynamic> json) =>
      DriverAccountCredentials(
        email: json['email'] as String,
        password: json['password'] as String,
      );
}

class DriverCreated {
  const DriverCreated({required this.driver, this.account});

  final Driver driver;
  final DriverAccountCredentials? account;

  factory DriverCreated.fromJson(Map<String, dynamic> json) {
    final account = json['account'];
    return DriverCreated(
      driver: Driver.fromJson(json),
      account: account is Map<String, dynamic>
          ? DriverAccountCredentials.fromJson(account)
          : null,
    );
  }
}

/// Result of POST /drivers/scan-license. Nothing is saved yet — the
/// operator reviews these fields (filling in anything the scanner missed)
/// and then submits [toCreateJson] to POST /drivers.
class LicenseScan {
  LicenseScan({
    required this.front,
    required this.back,
    required this.missingFields,
    required this.scanComplete,
  });

  /// Raw front-of-license fields, kept so every scanned value is saved.
  final Map<String, dynamic> front;
  final Map<String, dynamic> back;
  final List<String> missingFields;
  final bool scanComplete;

  factory LicenseScan.fromJson(Map<String, dynamic> json) => LicenseScan(
        front: Map<String, dynamic>.from(json['front'] as Map? ?? const {}),
        back: Map<String, dynamic>.from(json['back'] as Map? ?? const {}),
        missingFields: [
          for (final f in json['missing_fields'] as List? ?? const []) f as String,
        ],
        scanComplete: json['scan_complete'] as bool? ?? false,
      );

  String? get firstName => front['first_name'] as String?;
  String? get middleName => front['middle_name'] as String?;
  String? get lastName => front['last_name'] as String?;
  String? get licenseNumber => front['license_number'] as String?;
  DateTime? get expirationDate => _parseDate(front['expiration_date']);

  /// Body for POST /drivers: the scanned fields with the operator's
  /// reviewed values for the required ones.
  Map<String, dynamic> toCreateJson({
    required String firstName,
    required String lastName,
    String? middleName,
    required String licenseNumber,
    required DateTime expirationDate,
  }) {
    final middle = middleName?.trim();
    return {
      ...front,
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'middle_name': (middle == null || middle.isEmpty) ? null : middle,
      'license_number': licenseNumber.trim().toUpperCase(),
      'expiration_date': _isoDate(expirationDate),
      'serial_number': back['serial_number'],
    };
  }
}
