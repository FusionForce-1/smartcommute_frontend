// Security info
/// Security info
class SecurityInfo {
  /// Create security info
  const SecurityInfo({
    required this.twoFactorEnabled,
    required this.hasPassword,
    required this.termsCurrent,
    this.termsAcceptedAt,
    this.twoFactorBlocked,
  });

  /// Parse from JSON
  factory SecurityInfo.fromJson(Map<String, dynamic> json) {
    final accepted = json['terms_accepted_at'] as String?;
    return SecurityInfo(
      twoFactorEnabled: json['two_factor_enabled'] as bool? ?? false,
      hasPassword: json['has_password'] as bool? ?? true,
      termsCurrent: json['terms_current'] as bool? ?? false,
      termsAcceptedAt: accepted == null ? null : DateTime.tryParse(accepted),
      twoFactorBlocked: json['two_factor_blocked'] as String?,
    );
  }

  final bool twoFactorEnabled;

  final String? twoFactorBlocked;

  final bool hasPassword;

  final bool termsCurrent;
  final DateTime? termsAcceptedAt;

  /// Copy with changes
  SecurityInfo copyWith({bool? twoFactorEnabled}) => SecurityInfo(
        twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
        hasPassword: hasPassword,
        termsCurrent: termsCurrent,
        termsAcceptedAt: termsAcceptedAt,
        twoFactorBlocked: twoFactorBlocked,
      );
}
