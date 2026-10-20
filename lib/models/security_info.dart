// lib/models/security_info.dart
//
// What the Privacy & Security page shows (GET /users/me/security).

class SecurityInfo {
  const SecurityInfo({
    required this.twoFactorEnabled,
    required this.hasPassword,
    required this.termsCurrent,
    this.termsAcceptedAt,
  });

  factory SecurityInfo.fromJson(Map<String, dynamic> json) {
    final accepted = json['terms_accepted_at'] as String?;
    return SecurityInfo(
      twoFactorEnabled: json['two_factor_enabled'] as bool? ?? false,
      hasPassword: json['has_password'] as bool? ?? true,
      termsCurrent: json['terms_current'] as bool? ?? false,
      termsAcceptedAt: accepted == null ? null : DateTime.tryParse(accepted),
    );
  }

  final bool twoFactorEnabled;

  /// False for Google sign-ups that never set a password of their own.
  final bool hasPassword;

  /// Agreed to the current User Agreement / Privacy Policy.
  final bool termsCurrent;
  final DateTime? termsAcceptedAt;

  SecurityInfo copyWith({bool? twoFactorEnabled}) => SecurityInfo(
        twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
        hasPassword: hasPassword,
        termsCurrent: termsCurrent,
        termsAcceptedAt: termsAcceptedAt,
      );
}
