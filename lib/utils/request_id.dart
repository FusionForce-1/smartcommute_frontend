// lib/utils/request_id.dart
//
// A random id sent with a report or notice so the backend can tell a resend
// (after a dropped connection) from a new one, and store it only once.

import 'dart:math';

final Random _random = Random.secure();

/// 32 hex characters.
String newRequestId() =>
    List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
