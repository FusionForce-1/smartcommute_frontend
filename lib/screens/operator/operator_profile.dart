import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/transit_alert.dart' show OperatorProfile;
import '../../services/alerts_service.dart';
import '../../services/dio_interceptor.dart';
import '../../services/drivers_service.dart' show driverErrorMessage;

// Shared palette for the Profile > Operator Profile page.
const Color _pageColor = Color(0xFFF4F7F9);
const Color _borderColor = Color(0xFFE1E7EA);
const Color _blue = Color(0xFF2667C2);
const Color _titleColor = Color(0xFF111418);
const Color _mutedColor = Color(0xFF5F6B73);
const Color _green = Color(0xFF198754);
const Color _greenLight = Color(0xFFE4F4E9);
const Color _amber = Color(0xFFB77900);
const Color _amberLight = Color(0xFFFFF4DF);
const Color _red = Color(0xFFD93636);
const Color _teal = Color(0xFF2D7D86);

class OperatorProfileScreen extends StatefulWidget {
  const OperatorProfileScreen({super.key, this.service});

  /// Injected in tests; defaults to the authenticated app client.
  final AlertsService? service;

  @override
  State<OperatorProfileScreen> createState() => _OperatorProfileScreenState();
}

class _OperatorProfileScreenState extends State<OperatorProfileScreen> {
  late final AlertsService _service;

  OperatorProfile? _profile;
  bool _isLoading = true;
  String? _errorMessage;

  // GET /operators/me answered 404: the account has no company profile yet.
  bool _needsSetup = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AlertsService(buildDioClient());
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _needsSetup = false;
    });
    try {
      final profile = await _service.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final notFound = e is DioException && e.response?.statusCode == 404;
      setState(() {
        _needsSetup = notFound;
        _errorMessage =
            notFound ? null : driverErrorMessage(e, 'Unable to load your profile.');
        _isLoading = false;
      });
    }
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
                    'Profile',
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
              'Operator Profile',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: _titleColor,
              ),
            ),
          ),
          if (_profile != null)
            Text(
              _profile!.companyName,
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
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_needsSetup) {
      child = _ProfileSetupForm(service: _service, onCreated: _loadProfile);
    } else if (_errorMessage != null) {
      child = Padding(
        padding: const EdgeInsets.all(40),
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
              onPressed: _loadProfile,
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
      child = _buildDetails(_profile!);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: child,
    );
  }

  Widget _buildDetails(OperatorProfile profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _teal,
                child: Text(
                  profile.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.companyName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _titleColor,
                      ),
                    ),
                    if (profile.email != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.email!,
                        style: const TextStyle(fontSize: 14, color: _mutedColor),
                      ),
                    ],
                    const SizedBox(height: 6),
                    _verifiedChip(profile.isVerified),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _row('Company Name', profile.companyName),
          if (profile.fullName != null) _row('Account Owner', profile.fullName!),
          _row('Franchise Number', profile.franchiseNumber),
          _row('Contact Number', profile.contactNumber),
        ],
      ),
    );
  }

  Widget _verifiedChip(bool verified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: verified ? _greenLight : _amberLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        verified ? 'Verified Operator' : 'Pending Verification',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: verified ? _green : _amber,
        ),
      ),
    );
  }

  Widget _row(String label, String? value) {
    final missing = value == null || value.trim().isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: _mutedColor)),
          const SizedBox(height: 4),
          Text(
            missing ? 'Not provided' : value,
            style: TextStyle(
              fontSize: 15,
              color: missing ? const Color(0xFF9AA5AB) : _titleColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// Company profile setup (account has no operator profile yet)
// ===================================================================

class _ProfileSetupForm extends StatefulWidget {
  const _ProfileSetupForm({required this.service, required this.onCreated});

  final AlertsService service;
  final VoidCallback onCreated;

  @override
  State<_ProfileSetupForm> createState() => _ProfileSetupFormState();
}

class _ProfileSetupFormState extends State<_ProfileSetupForm> {
  final _company = TextEditingController();
  final _franchise = TextEditingController();
  final _contact = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_company, _franchise, _contact]) {
      c.addListener(() => setState(() => _error = null));
    }
  }

  @override
  void dispose() {
    for (final c in [_company, _franchise, _contact]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isComplete => _company.text.trim().length >= 2;

  String? _optional(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _save() async {
    if (!_isComplete || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.createProfile(
        companyName: _company.text.trim(),
        franchiseNumber: _optional(_franchise),
        contactNumber: _optional(_contact),
      );
      if (!mounted) return;
      widget.onCreated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = driverErrorMessage(e, 'Unable to save your profile.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Set up your company profile',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your account has no company profile yet. Add your details so '
            'commuters and drivers can see who operates your routes.',
            style: TextStyle(fontSize: 13.5, color: _mutedColor),
          ),
          const SizedBox(height: 18),
          _field('Company Name', _company, 'e.g. Cebu City Transport Co.'),
          const SizedBox(height: 14),
          _field('Franchise Number', _franchise, 'e.g. FR-2024-001'),
          const SizedBox(height: 14),
          _field(
            'Contact Number',
            _contact,
            'e.g. 09171234567',
            keyboardType: TextInputType.phone,
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ -]'))],
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: _red, fontSize: 14)),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _isComplete && !_saving ? _save : null,
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              disabledBackgroundColor: _blue.withValues(alpha: 0.35),
              disabledForegroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Profile'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _titleColor,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: !_saving,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9AA5AB), fontSize: 14),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            enabledBorder: border(_teal),
            focusedBorder: border(_teal, 1.8),
            disabledBorder: border(_borderColor),
          ),
        ),
      ],
    );
  }
}
