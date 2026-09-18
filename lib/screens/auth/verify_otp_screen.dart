// lib/screens/auth/verify_otp_screen.dart
//
// Emae D. Calonia — Flutter Verify OTP.
// Envelope icon, destination email, 6-digit code, Verify OTP.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../widgets/auth/auth_header_banner.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/error_banner.dart';

class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({
    super.key,
    required this.email,
    this.onVerifyOtp,
    this.onBack,
  });

  final String email;

  /// TODO: Velez — AuthProvider.verifyOtpAndResetPassword(email, otp, newPassword)
  /// → ApiService.verifyOtpAndResetPassword() → POST /auth/reset-password
  /// Mockups do not collect a new password on this screen; pass '' for preview
  /// or add a follow-up set-password step before the live endpoint.
  final Future<void> Function(String otp)? onVerifyOtp;
  final VoidCallback? onBack;

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otp = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Velez — on 200, notifyListeners() and pop to Login
      await widget.onVerifyOtp?.call(_otp.text.trim());
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Incorrect or expired code. Try again.',
        );
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
                      const Center(
                        child: Icon(
                          AppIcons.otpEnvelope,
                          color: AppColors.secondary,
                          size: 72,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Enter OTP',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                          children: [
                            const TextSpan(text: 'We sent a 6-digit code to\n'),
                            TextSpan(
                              text: widget.email,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_errorMessage != null) ...[
                        ErrorBanner(message: _errorMessage!),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      AuthTextField(
                        label: 'OTP Code',
                        hint: 'Enter 6-digit code',
                        controller: _otp,
                        pill: true,
                        maxLength: 6,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) => (v == null || v.trim().length != 6)
                            ? 'Enter the 6-digit code'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ElevatedButton(
                        onPressed: _handleVerify,
                        child: const Text('Verify OTP'),
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
