// Set new password screen
import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../widgets/auth/auth_header_banner.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/error_banner.dart';

/// Set new password screen
class SetNewPasswordScreen extends StatefulWidget {
  /// Create set new password
  const SetNewPasswordScreen({
    super.key,
    this.onResetPassword,
    this.onBack,
  });

  final Future<void> Function(String newPassword)? onResetPassword;
  final VoidCallback? onBack;

  /// Create widget state
  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

/// Set new password state
class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _repeatPassword = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  /// Clean up resources
  @override
  void dispose() {
    _password.dispose();
    _repeatPassword.dispose();
    super.dispose();
  }

  /// Handle reset
  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    if (_password.text != _repeatPassword.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onResetPassword?.call(_password.text);
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Incorrect or expired code. Go back and request a new one.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Build the widget
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
                          AppIcons.lock,
                          color: AppColors.secondary,
                          size: 72,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Set New Password',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose a new password for your account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_errorMessage != null) ...[
                        ErrorBanner(message: _errorMessage!),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      AuthTextField(
                        label: 'New Password',
                        hint: 'New Password',
                        controller: _password,
                        pill: true,
                        obscureText: true,
                        validator: (v) => (v == null || v.length < 8)
                            ? 'Minimum 8 characters'
                            : null,
                      ),
                      AuthTextField(
                        label: 'Repeat Password',
                        hint: 'Repeat Password',
                        controller: _repeatPassword,
                        pill: true,
                        obscureText: true,
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Repeat your password'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ElevatedButton(
                        onPressed: _handleReset,
                        child: const Text('Reset Password'),
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
