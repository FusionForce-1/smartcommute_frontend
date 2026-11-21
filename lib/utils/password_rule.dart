// Password rule
import 'dart:convert';

/// New password problem
String? passwordProblem(String? value) {
  final v = value ?? '';
  if (v.length < 8) return 'Minimum 8 characters';
  if (utf8.encode(v).length > 72) return 'Maximum 72 bytes';
  if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
    return 'Use at least one letter and one number';
  }
  return null;
}
