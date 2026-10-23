// lib/screens/commuter/privacy_security_screen.dart
//
// Privacy & Security (Profile → Account): change password, two-factor
// sign-in, when the commuter agreed to the User Agreement / Privacy
// Policy, and their data rights.

import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import '../../constants/legal_text.dart';
import '../../constants/support.dart';
import '../../models/security_info.dart';
import '../../services/api_error.dart';
import '../../services/profile_service.dart';
import '../../widgets/auth/consent_checkbox.dart';
import '../../widgets/commuter/settings_group.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key, required this.service});

  final ProfileService service;

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  SecurityInfo? _info;
  String? _loadError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final info = await widget.service.security();
      if (mounted) setState(() => _info = info);
    } catch (e) {
      if (mounted) setState(() => _loadError = apiErrorMessage(e));
    }
  }

  void _toast(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  /// Runs [action] with the page marked busy; shows its error, if any.
  Future<bool> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } catch (e) {
      if (mounted) _toast(apiErrorMessage(e));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangePasswordDialog(service: widget.service),
    );
    if (changed == true && mounted) _toast('Your password was changed.');
  }

  Future<void> _setTwoFactor(bool on) async {
    final info = _info!;
    if (on) {
      String? sentTo;
      if (!await _run(() async => sentTo = await widget.service.startTwoFactor())) return;
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _TwoFactorCodeDialog(service: widget.service, sentTo: sentTo!),
      );
      if (confirmed == true && mounted) {
        setState(() => _info = info.copyWith(twoFactorEnabled: true));
        _toast('Two-factor sign-in is on.');
      }
      return;
    }
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Turn off two-factor sign-in?'),
        content: const Text('Signing in will only need your password.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Turn off'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    if (await _run(widget.service.turnOffTwoFactor) && mounted) {
      setState(() => _info = info.copyWith(twoFactorEnabled: false));
    }
  }

  Future<void> _agree() async {
    SecurityInfo? updated;
    if (await _run(() async => updated = await widget.service.acceptTerms()) && mounted) {
      setState(() => _info = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      appBar: AppBar(
        backgroundColor: AppColors.brandTeal,
        foregroundColor: Colors.white,
        title: const Text('Privacy & Security'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    final info = _info;
    if (info == null) {
      if (_loadError == null) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    return AbsorbPointer(
      absorbing: _busy,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          const _Heading('Sign-in'),
          SettingsGroup(
            children: [
              if (info.hasPassword)
                SettingsLinkRow(
                  icon: Icons.lock_outline,
                  label: 'Change password',
                  onTap: _changePassword,
                )
              else
                const ListTile(
                  leading: Icon(Icons.lock_outline, color: AppColors.brandTeal),
                  title: Text('You sign in with Google'),
                  subtitle: Text(
                    'There is no SmartCommute password to change. To set one, sign out and '
                    'use "Forgot Password?" on the sign-in screen.',
                  ),
                ),
              SettingsSwitchRow(
                title: 'Two-factor sign-in',
                subtitle: 'Also ask for a code sent to your email when signing in.',
                value: info.twoFactorEnabled,
                onChanged: _setTwoFactor,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _Heading('Your agreement'),
          SettingsGroup(
            children: [
              ListTile(
                leading: Icon(
                  info.termsCurrent ? Icons.verified_outlined : Icons.info_outline,
                  color: info.termsCurrent ? AppColors.success : AppColors.accent,
                ),
                title: Text(
                  info.termsCurrent
                      ? 'You agreed on ${_formatDate(info.termsAcceptedAt)}'
                      : "You haven't agreed to the latest terms",
                ),
                subtitle: Text(
                  info.termsCurrent
                      ? 'To the User Agreement and Privacy Policy.'
                      : 'Please read the User Agreement and Privacy Policy, then agree to keep '
                          'a record on your account.',
                ),
              ),
              SettingsLinkRow(
                icon: Icons.description_outlined,
                label: 'User Agreement',
                onTap: () => showLegalDoc(context, userAgreement),
              ),
              SettingsLinkRow(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () => showLegalDoc(context, privacyPolicy),
              ),
              if (!info.termsCurrent)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: FilledButton(
                    onPressed: _agree,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brandTeal),
                    child: const Text('I agree'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _Heading('Your data'),
          SettingsGroup(
            children: [
              const ListTile(
                leading: Icon(Icons.shield_outlined, color: AppColors.brandTeal),
                title: Text('Your rights under the Data Privacy Act'),
                subtitle: Text(
                  'You can ask for a copy of your personal data, or for it to be corrected or '
                  'deleted. We do not sell your data.',
                ),
              ),
              if (hasSupportEmail)
                SettingsLinkRow(
                  icon: Icons.mail_outline,
                  label: 'Request my data or account deletion',
                  onTap: () => emailSupport(context, subject: 'SmartCommute data request'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "October 20, 2026" in the phone's time zone.
String _formatDate(DateTime? date) {
  if (date == null) return 'an earlier date';
  final local = date.toLocal();
  return '${_months[local.month - 1]} ${local.day}, ${local.year}';
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.service});

  final ProfileService service;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    String? problem;
    if (_current.text.isEmpty || _next.text.isEmpty) {
      problem = 'Fill in your current and new password.';
    } else if (_next.text.length < 6) {
      problem = 'New password must be at least 6 characters.';
    } else if (_next.text != _repeat.text) {
      problem = 'New passwords do not match.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.changePassword(current: _current.text, next: _next.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = apiErrorMessage(e);
          _saving = false;
        });
      }
    }
  }

  Widget _field(String label, TextEditingController controller) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(labelText: label),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field('Current password', _current),
            _field('New password', _next),
            _field('Repeat new password', _repeat),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}

class _TwoFactorCodeDialog extends StatefulWidget {
  const _TwoFactorCodeDialog({required this.service, required this.sentTo});

  final ProfileService service;
  final String sentTo;

  @override
  State<_TwoFactorCodeDialog> createState() => _TwoFactorCodeDialogState();
}

class _TwoFactorCodeDialogState extends State<_TwoFactorCodeDialog> {
  final _code = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.confirmTwoFactor(code);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = apiErrorMessage(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Turn on two-factor sign-in'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('We sent a 6-digit code to ${widget.sentTo}.'),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'Code'),
            onSubmitted: (_) => _confirm(),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _saving ? null : _confirm, child: const Text('Turn on')),
      ],
    );
  }
}
