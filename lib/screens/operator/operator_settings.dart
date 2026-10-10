import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/alerts_service.dart';
import '../../services/dio_interceptor.dart';
import '../../services/drivers_service.dart' show driverErrorMessage;
import '../../services/settings_service.dart';

// Shared palette for the Settings page.
const Color _pageColor = Color(0xFFF4F7F9);
const Color _borderColor = Color(0xFFE1E7EA);
const Color _blue = Color(0xFF2667C2);
const Color _titleColor = Color(0xFF111418);
const Color _mutedColor = Color(0xFF5F6B73);
const Color _red = Color(0xFFD93636);
const Color _teal = Color(0xFF2D7D86);

class OperatorSettings extends StatefulWidget {
  const OperatorSettings({super.key, this.service, this.profileService});

  /// Injected in tests; default to the authenticated app client.
  final SettingsService? service;
  final AlertsService? profileService;

  @override
  State<OperatorSettings> createState() => _OperatorSettingsState();
}

class _OperatorSettingsState extends State<OperatorSettings> {
  late final SettingsService _service;
  late final AlertsService _profileService;

  AccountSettings? _settings;
  bool _isLoading = true;
  String? _errorMessage;
  String? _companyName;

  // The setting being saved, so its control shows as busy.
  String? _saving;

  @override
  void initState() {
    super.initState();
    final dio = (widget.service == null || widget.profileService == null)
        ? buildDioClient()
        : null;
    _service = widget.service ?? SettingsService(dio!);
    _profileService = widget.profileService ?? AlertsService(dio!);
    _loadSettings();
    _loadCompanyName();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final settings = await _service.getSettings();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = driverErrorMessage(e, 'Unable to load your settings.');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCompanyName() async {
    try {
      final profile = await _profileService.getProfile();
      if (!mounted) return;
      setState(() => _companyName = profile.companyName);
    } catch (_) {
      // The header just shows no company name.
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? _red : null),
    );
  }

  Future<void> _save(String key, Future<AccountSettings> Function() request,
      String doneMessage) async {
    setState(() => _saving = key);
    try {
      final settings = await request();
      if (!mounted) return;
      setState(() => _settings = settings);
      _showMessage(doneMessage);
    } catch (e) {
      if (!mounted) return;
      _showMessage(driverErrorMessage(e, 'Unable to save your settings.'), error: true);
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  void _setEmailNotifications(bool on) => _save(
        'email',
        () => _service.update(emailNotifications: on),
        on ? 'Email notifications turned on.' : 'Email notifications turned off.',
      );

  void _setLanguage(String language) => _save(
        'language',
        () => _service.update(language: language),
        'Language updated.',
      );

  Future<void> _setTwoFactor(bool on) async {
    if (on) {
      final settings = await showDialog<AccountSettings>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EnableTwoFactorDialog(service: _service),
      );
      if (settings == null || !mounted) return;
      setState(() => _settings = settings);
      _showMessage('Two-factor authentication is on.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Turn off two-factor authentication?',
          style: TextStyle(fontWeight: FontWeight.w800, color: _titleColor),
        ),
        content: const Text(
          'You will sign in with just your password. Your account will be '
          'less protected if your password is ever leaked.',
          style: TextStyle(color: _mutedColor, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _red,
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Turn Off'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _save('2fa', _service.disableTwoFactor, 'Two-factor authentication is off.');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _pageColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, 36, 38, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _titleColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _buildCard(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Settings',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: _titleColor,
              ),
            ),
          ),
          if (_companyName != null)
            Text(
              _companyName!,
              style: const TextStyle(fontSize: 17, color: _mutedColor),
            ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    final Widget child;
    if (_isLoading) {
      child = const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_errorMessage != null) {
      child = Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44, color: _red),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _red, fontSize: 15),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadSettings,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _blue,
                side: const BorderSide(color: _blue),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    } else {
      final s = _settings!;
      child = Column(
        children: [
          _row(
            title: 'Email Notifications',
            subtitle: 'Receive alerts and updates via email',
            trailing: _switch(
              value: s.emailNotifications,
              busy: _saving == 'email',
              onChanged: _setEmailNotifications,
            ),
          ),
          const Divider(height: 1, color: _borderColor),
          _row(
            title: 'Two-Factor Authentication',
            subtitle: s.twoFactorEnabled
                ? 'On — a code is emailed each time you sign in'
                : 'Extra security for your account',
            trailing: _switch(
              value: s.twoFactorEnabled,
              busy: _saving == '2fa',
              onChanged: _setTwoFactor,
            ),
          ),
          const Divider(height: 1, color: _borderColor),
          _row(
            title: 'Language',
            subtitle: s.languageLabel,
            trailing: _languagePicker(s.language),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: child,
    );
  }

  Widget _row({required String title, required String subtitle, required Widget trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _titleColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: _mutedColor)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }

  Widget _switch({
    required bool value,
    required bool busy,
    required ValueChanged<bool> onChanged,
  }) {
    return Switch(
      value: value,
      onChanged: busy || _saving != null ? null : onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: _teal,
    );
  }

  Widget _languagePicker(String current) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: appLanguages.containsKey(current) ? current : null,
        borderRadius: BorderRadius.circular(10),
        style: const TextStyle(fontSize: 14, color: _titleColor),
        onChanged: _saving != null
            ? null
            : (value) {
                if (value != null && value != current) _setLanguage(value);
              },
        items: [
          for (final entry in appLanguages.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
      ),
    );
  }
}

// ===================================================================
// Turn on two-factor: email a code, then confirm it
// ===================================================================

class _EnableTwoFactorDialog extends StatefulWidget {
  const _EnableTwoFactorDialog({required this.service});

  final SettingsService service;

  @override
  State<_EnableTwoFactorDialog> createState() => _EnableTwoFactorDialogState();
}

class _EnableTwoFactorDialogState extends State<_EnableTwoFactorDialog> {
  final _code = TextEditingController();

  bool _sending = true;
  bool _verifying = false;
  String? _sentTo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() => _error = null));
    _sendCode();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final sentTo = await widget.service.startTwoFactor();
      if (!mounted) return;
      setState(() {
        _sentTo = sentTo;
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = driverErrorMessage(e, 'Unable to send the code.');
      });
    }
  }

  Future<void> _verify() async {
    if (_code.text.length != 6 || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final settings = await widget.service.confirmTwoFactor(_code.text);
      if (!mounted) return;
      Navigator.of(context).pop(settings);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = driverErrorMessage(e, 'Incorrect or expired code.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _sending || _verifying;
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Turn on two-factor authentication',
        style: TextStyle(fontWeight: FontWeight.w800, color: _titleColor),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _sending
                  ? 'Sending a code to your email…'
                  : _sentTo == null
                      ? 'We need to email you a code to confirm this change.'
                      : 'Enter the 6-digit code we sent to $_sentTo. You will '
                          'also need a code like this each time you sign in.',
              style: const TextStyle(color: _mutedColor, fontSize: 14.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              enabled: !busy && _sentTo != null,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w700),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onSubmitted: (_) => _verify(),
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: const TextStyle(color: Color(0xFFC3CBD0), letterSpacing: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _teal, width: 1.8),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: _red, fontSize: 14)),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: busy ? null : _sendCode,
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: const Text('Send a new code'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _verifying ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: !busy && _code.text.length == 6 ? _verify : null,
          style: FilledButton.styleFrom(
            backgroundColor: _blue,
            minimumSize: const Size(0, 44),
          ),
          child: _verifying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Turn On'),
        ),
      ],
    );
  }
}
