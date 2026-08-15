// lib/screens/auth/verify_otp_screen.dart
//
// E2. Flutter Mobile App Screens — VerifyOtpScreen
// File: screens/auth/verify_otp_screen.dart · Role: All roles
// "Teal header banner 'FORGOT PASSWORD'. Envelope icon, 'Enter OTP' heading,
// masked destination email, 6-digit code field, 'Verify OTP' button."
//
// UI-only.TODO:
//   onVerifyOtp -> AuthService.verify_otp(email, otp) + reset_password() ->
//                  POST /auth/reset-password -> HTTP 200

import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
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

  /// The email the OTP was (supposedly) sent to — display only, masked by
  /// the caller if desired.
  final String email;

  /// TODO: wire to the real "verify OTP" API call.
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

    if (widget.onVerifyOtp != null) {
      try {
        await widget.onVerifyOtp!(_otp.text.trim());
      } catch (e) {
        setState(() => _errorMessage = 'Incorrect or expired code. Try again.');
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preview only — Verify OTP not wired yet.')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
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
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.mail_outline,
                            color: AppColors.secondary,
                            size: 56,
                          ),
                        ),
                      ),
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
                              color: AppColors.textSecondary, fontSize: 14),
                          children: [
                            const TextSpan(text: 'We sent a 6-digit code to '),
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
                        keyboardType: TextInputType.number,
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
