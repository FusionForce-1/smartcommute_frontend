// lib/screens/auth/forgot_password_screen.dart
//
// Emae D. Calonia — Flutter Forgot Password.
// Shield + lock icon, email field, Send OTP.

import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../widgets/auth/auth_header_banner.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/error_banner.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.onSendOtp,
    this.onBack,
  });

  /// TODO: Velez — AuthProvider.sendPasswordResetOtp(email)
  /// → ApiService.sendPasswordResetOtp() → POST /auth/forgot-password (HTTP 202)
  final Future<void> Function(String email)? onSendOtp;
  final VoidCallback? onBack;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Velez — on success, push VerifyOtpScreen(email) and keep provider loading false
      await widget.onSendOtp?.call(_email.text.trim());
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'This email is not registered.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthHeaderBanner(
                title: 'FORGOT\nPASSWORD',
                onBack: widget.onBack,
                big: true,
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      const Center(child: _ShieldLockMark()),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Trouble Logging in?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Enter your email and we'll send you an OTP code to reset your password.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_errorMessage != null) ...[
                        ErrorBanner(message: _errorMessage!),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      AuthTextField(
                        label: 'Email Address',
                        hint: 'Email',
                        controller: _email,
                        pill: true,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Enter a valid email'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ElevatedButton(
                        onPressed: _handleSendOtp,
                        child: const Text('Send OTP'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShieldLockMark extends StatelessWidget {
  const _ShieldLockMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            AppIcons.forgotShield,
            size: 84,
            color: AppColors.secondary,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Icon(
              AppIcons.lock,
              size: 28,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
