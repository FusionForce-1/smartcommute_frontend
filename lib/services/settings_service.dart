import 'package:dio/dio.dart';

/// Languages the app is available in: backend code -> display name.
const Map<String, String> appLanguages = {'en-PH': 'English (Philippines)'};

/// GET/PATCH /users/me/settings.
class AccountSettings {
  const AccountSettings({
    required this.emailNotifications,
    required this.twoFactorEnabled,
    required this.language,
  });

  final bool emailNotifications;
  final bool twoFactorEnabled;
  final String language;

  factory AccountSettings.fromJson(Map<String, dynamic> json) => AccountSettings(
        emailNotifications: json['email_notifications'] as bool? ?? true,
        twoFactorEnabled: json['two_factor_enabled'] as bool? ?? false,
        language: json['language'] as String? ?? 'en-PH',
      );

  String get languageLabel => appLanguages[language] ?? language;
}

/// The signed-in user's account settings and two-factor authentication.
class SettingsService {
  SettingsService(this._dio);

  final Dio _dio;

  Future<AccountSettings> getSettings() async {
    final response = await _dio.get('/users/me/settings');
    return AccountSettings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AccountSettings> update({bool? emailNotifications, String? language}) =>
      _patch({
        if (emailNotifications != null) 'email_notifications': emailNotifications,
        if (language != null) 'language': language,
      });

  Future<AccountSettings> disableTwoFactor() => _patch({'two_factor_enabled': false});

  /// Emails a code to confirm with [confirmTwoFactor]. Returns where it went.
  Future<String> startTwoFactor() async {
    final response = await _dio.post('/users/me/two-factor/start');
    return (response.data as Map<String, dynamic>)['email'] as String? ?? 'your email';
  }

  Future<AccountSettings> confirmTwoFactor(String otp) async {
    final response = await _dio.post('/users/me/two-factor/confirm', data: {'otp': otp});
    return AccountSettings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AccountSettings> _patch(Map<String, dynamic> body) async {
    final response = await _dio.patch('/users/me/settings', data: body);
    return AccountSettings.fromJson(response.data as Map<String, dynamic>);
  }
}
