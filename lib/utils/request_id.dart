// Request ID
import 'dart:math';

final Random _random = Random.secure();

/// New request ID
String newRequestId() =>
    List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
