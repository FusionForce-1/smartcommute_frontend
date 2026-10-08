import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/driver.dart';
import '../../services/dio_interceptor.dart';
import '../../services/drivers_service.dart';

// Shared palette for the Fleet > Driver Management page.
const Color _pageColor = Color(0xFFF4F7F9);
const Color _borderColor = Color(0xFFE1E7EA);
const Color _blue = Color(0xFF2667C2);
const Color _blueLight = Color(0xFFEAF1FA);
const Color _titleColor = Color(0xFF111418);
const Color _mutedColor = Color(0xFF5F6B73);
const Color _green = Color(0xFF198754);
const Color _greenLight = Color(0xFFE4F4E9);
const Color _red = Color(0xFFD93636);
const Color _amber = Color(0xFFB77900);
const Color _amberLight = Color(0xFFFFF4DF);

const TextStyle _monoStyle = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Consolas', 'Courier New'],
  fontSize: 14,
  fontWeight: FontWeight.w700,
  color: Color(0xFF1F2A30),
);

final RegExp _licensePattern = RegExp(r'^[A-Z]\d{2}-\d{2}-\d{6}$');

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Dec 18, 2028"
String _formatDate(DateTime d) =>
    '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';

class OperatorVehicles extends StatefulWidget {
  const OperatorVehicles({super.key, this.service});

  /// Injected in tests; defaults to the authenticated app client.
  final DriversService? service;

  @override
  State<OperatorVehicles> createState() => _OperatorVehiclesState();
}

class _OperatorVehiclesState extends State<OperatorVehicles> {
  late final DriversService _service;

  List<Driver> _drivers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _companyName;

  // GET /drivers does not include the login email, so remember the ones
  // the backend returned when a driver was created or their password set.
  final Map<String, String> _knownEmails = {};

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DriversService(buildDioClient());
    _loadDrivers();
    _loadCompanyName();
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final drivers = await _service.getDrivers();
      if (!mounted) return;
      setState(() {
        _drivers = drivers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = driverErrorMessage(e, 'Unable to load drivers.');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCompanyName() async {
    try {
      final name = await _service.getCompanyName();
      if (!mounted) return;
      setState(() => _companyName = name);
    } catch (_) {
      // The header just shows no company name.
    }
  }

  String? _emailFor(Driver driver) => driver.email ?? _knownEmails[driver.id];

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? _red : null,
      ),
    );
  }

  Future<void> _openAddDriver() async {
    final created = await showDialog<DriverCreated>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x8A587896),
      builder: (_) => _AddDriverDialog(service: _service),
    );
    if (created == null || !mounted) return;

    final email = created.account?.email ?? created.driver.email;
    if (email != null) _knownEmails[created.driver.id] = email;
    setState(() => _drivers = [..._drivers, created.driver]);

    if (created.account != null) {
      await showDialog<void>(
        context: context,
        builder: (_) => _CredentialsDialog(
          driver: created.driver,
          account: created.account!,
        ),
      );
    } else {
      _showMessage('${created.driver.displayName} was added.');
    }
  }

  void _openDetails(Driver driver) {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0x8A587896),
      builder: (_) => _DriverDetailsDialog(driver: driver, email: _emailFor(driver)),
    );
  }

  Future<void> _openChangePassword(Driver driver) async {
    final email = await showDialog<String>(
      context: context,
      barrierColor: const Color(0x8A587896),
      builder: (_) => _ChangePasswordDialog(
        service: _service,
        driver: driver,
        email: _emailFor(driver),
      ),
    );
    if (email == null || !mounted) return;
    if (email.isNotEmpty) setState(() => _knownEmails[driver.id] = email);
    _showMessage('Password updated for ${driver.displayName}.');
  }

  Future<void> _confirmDelete(Driver driver) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Remove driver?',
          style: TextStyle(fontWeight: FontWeight.w800, color: _titleColor),
        ),
        content: Text(
          '${driver.displayName} (${driver.driverCode}) will be removed from '
          'your roster. This cannot be undone.',
          style: const TextStyle(color: _mutedColor, fontSize: 15),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _service.deleteDriver(driver.id);
      if (!mounted) return;
      setState(() {
        _drivers = _drivers.where((d) => d.id != driver.id).toList();
        _knownEmails.remove(driver.id);
      });
      _showMessage('${driver.displayName} was removed.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(driverErrorMessage(e, 'Unable to remove driver.'), error: true);
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
              padding: const EdgeInsets.fromLTRB(40, 48, 38, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildDriverRoster(),
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
              'Driver Management',
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

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Drivers',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _titleColor,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Manage authorized drivers and verify their license records.',
                style: TextStyle(fontSize: 16.5, color: _mutedColor),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ElevatedButton.icon(
            onPressed: _openAddDriver,
            icon: const Icon(Icons.add, size: 24),
            label: const Text('Add Driver'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: _blue.withValues(alpha: 0.35),
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverRoster() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRosterHeader(),
          const Divider(height: 1, color: _borderColor),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            _buildErrorState()
          else if (_drivers.isEmpty)
            _buildEmptyState()
          else
            _buildDriverTable(),
        ],
      ),
    );
  }

  Widget _buildRosterHeader() {
    final count = _drivers.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 22),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _blueLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.people_outline, color: _blue, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Driver Roster',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: _titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isLoading
                      ? 'Loading drivers…'
                      : '$count registered ${count == 1 ? 'driver' : 'drivers'}',
                  style: const TextStyle(fontSize: 14, color: _mutedColor),
                ),
              ],
            ),
          ),
          if (!_isLoading && _errorMessage == null && _drivers.isNotEmpty)
            _buildLicenseChip(),
        ],
      ),
    );
  }

  Widget _buildLicenseChip() {
    final expired = _drivers.where((d) => d.isLicenseExpired()).length;
    final ok = expired == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: ok ? _greenLight : _amberLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            size: 18,
            color: ok ? _green : _amber,
          ),
          const SizedBox(width: 7),
          Text(
            ok
                ? 'Licenses verified'
                : '$expired ${expired == 1 ? 'license' : 'licenses'} expired',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ok ? _green : _amber,
            ),
          ),
        ],
      ),
    );
  }

  // Column widths, shared by the header row and the data rows.
  static const List<int> _flex = [3, 5, 3, 3, 3, 4];
  static const double _minTableWidth = 900;

  Widget _buildDriverTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, _minTableWidth);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTableHeader(),
                for (int i = 0; i < _drivers.length; i++) ...[
                  const Divider(height: 1, color: _borderColor),
                  _buildDriverRow(_drivers[i]),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tableRow(List<Widget> cells, {double vertical = 22, VoidCallback? onTap}) {
    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: 30, vertical: vertical),
      child: Row(
        children: [
          for (int i = 0; i < cells.length; i++)
            Expanded(
              flex: _flex[i],
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Align(alignment: Alignment.centerLeft, child: cells[i]),
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.white,
      child: InkWell(onTap: onTap, hoverColor: const Color(0xFFF7FAFD), child: row),
    );
  }

  Widget _buildTableHeader() {
    const style = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Color(0xFF53636B),
    );
    return Container(
      color: const Color(0xFFF7F9FB),
      child: _tableRow(
        const [
          Text('Driver', style: style),
          Text('Driver Account', style: style),
          Text('License Number', style: style),
          Text('License Expiry', style: style),
          Text('Status', style: style),
          Text('Actions', style: style),
        ],
        vertical: 24,
      ),
    );
  }

  Widget _buildDriverRow(Driver driver) {
    final email = _emailFor(driver);
    final expired = driver.isLicenseExpired();

    return _tableRow(onTap: () => _openDetails(driver), [
      // Driver
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            driver.displayName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            driver.driverCode,
            style: const TextStyle(fontSize: 14, color: _mutedColor),
          ),
        ],
      ),

      // Driver Account
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (email != null)
            Text(email, overflow: TextOverflow.ellipsis, style: _monoStyle)
          else
            const Text(
              'Email not on record',
              style: TextStyle(fontSize: 14, color: _mutedColor),
            ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.key_outlined, size: 16, color: Color(0xFF8A969D)),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Password protected',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, color: Color(0xFF8A969D)),
                ),
              ),
            ],
          ),
        ],
      ),

      // License Number
      Row(
        children: [
          Tooltip(
            message: expired ? 'License expired' : 'License valid',
            child: Icon(
              expired ? Icons.error_outline : Icons.check_circle_outline,
              size: 17,
              color: expired ? _red : _green,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(child: Text(driver.licenseNumber, style: _monoStyle)),
        ],
      ),

      // License Expiry
      Text(
        _formatDate(driver.expirationDate),
        style: TextStyle(
          fontSize: 17,
          color: expired ? _red : const Color(0xFF53636B),
        ),
      ),

      // Status
      _statusBadge(driver),

      // Actions
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _openChangePassword(driver),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Password'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _blue,
              side: const BorderSide(color: _blue),
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          SizedBox(
            width: 36,
            height: 36,
            child: OutlinedButton(
              onPressed: () => _confirmDelete(driver),
              style: OutlinedButton.styleFrom(
                foregroundColor: _red,
                side: const BorderSide(color: _red),
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Icon(Icons.delete_outline, size: 20),
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _statusBadge(Driver driver) {
    final active = driver.isActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? _greenLight : const Color(0xFFF0F1F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Active' : 'Off Duty',
        softWrap: false,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: active ? _green : const Color(0xFF687077),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(48),
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
            onPressed: _loadDrivers,
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
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No drivers yet. Add a driver by scanning their license.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// Add New Driver dialog
// ===================================================================

class _AddDriverDialog extends StatefulWidget {
  const _AddDriverDialog({required this.service});

  final DriversService service;

  @override
  State<_AddDriverDialog> createState() => _AddDriverDialogState();
}

class _AddDriverDialogState extends State<_AddDriverDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _licenseNumber = TextEditingController();
  DateTime? _expiry;

  LicenseImage? _front;
  LicenseImage? _back;

  bool _scanning = false;
  String? _scanError;
  LicenseScan? _scan;
  // Bumped whenever a photo changes so a stale scan result is ignored.
  int _scanId = 0;

  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _licenseNumber.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool front}) async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        dialogTitle: front ? 'Front of license' : 'Back of license',
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg'],
      );
    } catch (_) {
      setState(() => _scanError = 'Could not open the image picker.');
      return;
    }
    if (file == null) return;

    final ext = file.extension?.toLowerCase();
    if (ext != 'png' && ext != 'jpg' && ext != 'jpeg') {
      setState(() => _scanError = 'Please choose a PNG or JPG image.');
      return;
    }
    final image = LicenseImage(name: file.name, bytes: await file.readAsBytes());
    if (!mounted) return;

    setState(() {
      if (front) {
        _front = image;
      } else {
        _back = image;
      }
      _scanId++;
      _scan = null;
      _scanError = null;
      _scanning = false;
      _submitError = null;
    });
    if (_front != null && _back != null) _runScan();
  }

  Future<void> _runScan() async {
    final id = ++_scanId;
    setState(() {
      _scanning = true;
      _scanError = null;
    });
    try {
      final scan = await widget.service.scanLicense(front: _front!, back: _back!);
      if (!mounted || id != _scanId) return;
      _firstName.text = scan.firstName ?? '';
      _middleName.text = scan.middleName ?? '';
      _lastName.text = scan.lastName ?? '';
      _licenseNumber.text = scan.licenseNumber ?? '';
      setState(() {
        _scan = scan;
        _expiry = scan.expirationDate;
        _scanning = false;
      });
    } catch (e) {
      if (!mounted || id != _scanId) return;
      setState(() {
        _scanning = false;
        _scanError = driverErrorMessage(e, 'Could not read the license. Try clearer photos.');
      });
    }
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  String? _expiryProblem() {
    final expiry = _expiry;
    if (expiry == null) return 'Required';
    final now = DateTime.now();
    if (expiry.isBefore(DateTime(now.year, now.month, now.day))) {
      return 'This license has expired';
    }
    return null;
  }

  Future<void> _submit() async {
    final scan = _scan;
    if (scan == null) return;
    final formOk = _formKey.currentState!.validate();
    setState(() {}); // re-check the expiry field
    if (!formOk || _expiryProblem() != null) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final created = await widget.service.addDriver(scan.toCreateJson(
        firstName: _firstName.text,
        lastName: _lastName.text,
        middleName: _middleName.text,
        licenseNumber: _licenseNumber.text,
        expirationDate: _expiry!,
      ));
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = driverErrorMessage(e, 'Unable to add driver.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _scan != null && !_scanning && !_submitting;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const Divider(height: 1, color: _borderColor),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(34, 32, 34, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPhotosSection(),
                    if (_scanning) _buildScanning(),
                    if (_scanError != null) _buildBanner(_scanError!, retry: _canRetryScan),
                    if (_scan != null) _buildReviewSection(_scan!),
                    if (_submitError != null) _buildBanner(_submitError!),
                  ],
                ),
              ),
            ),
            _buildFooter(canSubmit),
          ],
        ),
      ),
    );
  }

  bool get _canRetryScan => _front != null && _back != null && !_scanning;

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 30, 24, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add New Driver',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _titleColor,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Upload both sides of the driver’s license. Driver information is filled automatically.',
                  style: TextStyle(fontSize: 16, color: _mutedColor),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 26, color: Color(0xFF3B4247)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Driver’s License Photos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _titleColor,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Use clear, uncropped photos. Both sides are required.',
                    style: TextStyle(fontSize: 14, color: _mutedColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _blueLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.document_scanner_outlined, size: 16, color: _blue),
                  SizedBox(width: 6),
                  Text(
                    'Auto-scan enabled',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final front = _UploadBox(
              title: 'Front of license',
              image: _front,
              enabled: !_submitting,
              onTap: () => _pickImage(front: true),
            );
            final back = _UploadBox(
              title: 'Back of license',
              image: _back,
              enabled: !_submitting,
              onTap: () => _pickImage(front: false),
            );
            if (constraints.maxWidth < 520) {
              return Column(children: [front, const SizedBox(height: 16), back]);
            }
            return Row(
              children: [
                Expanded(child: front),
                const SizedBox(width: 20),
                Expanded(child: back),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildScanning() {
    return const Padding(
      padding: EdgeInsets.only(top: 20),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: _blue),
          ),
          SizedBox(width: 12),
          Text(
            'Scanning license…',
            style: TextStyle(fontSize: 15, color: _blue, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(String message, {bool retry = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: _red, fontSize: 14.5)),
          ),
          if (retry)
            TextButton(
              onPressed: _runScan,
              style: TextButton.styleFrom(foregroundColor: _red),
              child: const Text('Retry scan'),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(LicenseScan scan) {
    final missing = scan.missingFields.toSet();
    final needsReview = {
      'first_name',
      'last_name',
      'license_number',
      'expiration_date',
    }.intersection(missing).length;

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driver Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _titleColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Filled from the license scan. Review before adding.',
                        style: TextStyle(fontSize: 14, color: _mutedColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: needsReview == 0 ? _greenLight : _amberLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    needsReview == 0
                        ? 'Scan complete'
                        : '$needsReview ${needsReview == 1 ? 'field needs' : 'fields need'} input',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: needsReview == 0 ? _green : _amber,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 520;
                final fieldWidth = twoColumns
                    ? (constraints.maxWidth - 20) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 20,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: _textField(
                        'First name',
                        _firstName,
                        missing: missing.contains('first_name'),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _textField(
                        'Last name',
                        _lastName,
                        missing: missing.contains('last_name'),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _textField('Middle name (optional)', _middleName, required: false),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _textField(
                        'License number',
                        _licenseNumber,
                        missing: missing.contains('license_number'),
                        hint: 'N01-23-456789',
                        validator: (value) {
                          final v = (value ?? '').trim().toUpperCase();
                          if (v.isEmpty) return 'Required';
                          if (!_licensePattern.hasMatch(v)) {
                            return 'Must look like N01-23-456789';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _expiryField(missing.contains('expiration_date')),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, {bool missing = false, String? hint}) {
    OutlineInputBorder border(Color color, [double width = 1.2]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    final base = missing ? _amber : const Color(0xFFD5DEE5);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: missing ? const Color(0xFFFFFBF2) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      helperText: missing ? 'Not readable on the scan — please fill in' : null,
      helperStyle: const TextStyle(color: _amber),
      border: border(base),
      enabledBorder: border(base),
      focusedBorder: border(_blue, 1.6),
      errorBorder: border(_red),
      focusedErrorBorder: border(_red, 1.6),
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    bool missing = false,
    bool required = true,
    String? hint,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_submitting,
      textCapitalization: TextCapitalization.characters,
      decoration: _decoration(label, missing: missing, hint: hint),
      validator: validator ??
          (required
              ? (value) => (value ?? '').trim().isEmpty ? 'Required' : null
              : null),
    );
  }

  Widget _expiryField(bool missing) {
    final problem = _scan != null && _expiry != null ? _expiryProblem() : null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _submitting ? null : _pickExpiry,
      child: InputDecorator(
        isEmpty: _expiry == null,
        decoration: _decoration('License expiry', missing: missing).copyWith(
          errorText: problem,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          _expiry == null ? '' : _formatDate(_expiry!),
          style: const TextStyle(fontSize: 16, color: _titleColor),
        ),
      ),
    );
  }

  Widget _buildFooter(bool canSubmit) {
    return Container(
      padding: const EdgeInsets.fromLTRB(34, 20, 34, 20),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: _blue,
              backgroundColor: Colors.white,
              side: const BorderSide(color: _blue, width: 1.4),
              minimumSize: const Size(106, 52),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: canSubmit ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFA9C6EA),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(138, 52),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('Add Driver'),
          ),
        ],
      ),
    );
  }
}

/// Dashed drop area for one side of the license.
class _UploadBox extends StatelessWidget {
  const _UploadBox({
    required this.title,
    required this.image,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final LicenseImage? image;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final picked = image;
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(color: _blue, radius: 16),
      child: Material(
        color: const Color(0xFFFCFDFF),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: 192,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (picked == null)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: _blueLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.image_outlined, color: _blue, size: 26),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        picked.bytes,
                        height: 64,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined, color: _red, size: 40),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF163B50),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    picked?.name ?? 'PNG or JPG · clear, uncropped image',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14.5, color: _mutedColor),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        picked == null ? Icons.upload_outlined : Icons.swap_horiz,
                        size: 18,
                        color: _blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        picked == null ? 'Choose image' : 'Change image',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0.8, 0.8, size.width - 1.6, size.height - 1.6),
        Radius.circular(radius),
      ));
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

// ===================================================================
// Generated login, shown once after a driver is added
// ===================================================================

class _CredentialsDialog extends StatelessWidget {
  const _CredentialsDialog({required this.driver, required this.account});

  final Driver driver;
  final DriverAccountCredentials account;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: _green),
          SizedBox(width: 10),
          Text(
            'Driver added',
            style: TextStyle(fontWeight: FontWeight.w800, color: _titleColor),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Give these sign-in details to ${driver.displayName}. '
              'The password is shown only once — copy it now.',
              style: const TextStyle(fontSize: 15, color: _mutedColor),
            ),
            const SizedBox(height: 18),
            _credentialRow(context, 'Email', account.email),
            const SizedBox(height: 10),
            _credentialRow(context, 'Password', account.password),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: _blue,
            minimumSize: const Size(96, 44),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _credentialRow(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(label, style: const TextStyle(color: _mutedColor)),
          ),
          Expanded(child: SelectableText(value, style: _monoStyle)),
          IconButton(
            tooltip: 'Copy $label',
            icon: const Icon(Icons.copy_outlined, size: 18, color: _blue),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copied')),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// Change a driver's login password
// ===================================================================

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({
    required this.service,
    required this.driver,
    required this.email,
  });

  final DriversService service;
  final Driver driver;
  final String? email;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  // Same rules as the backend (driver_credentials.password_problem).
  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.length < 8) return 'At least 8 characters';
    if (!v.contains(RegExp(r'[A-Za-z]')) || !v.contains(RegExp(r'\d'))) {
      return 'Use at least one letter and one number';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final email = await widget.service.updatePassword(widget.driver.id, _password.text);
      if (!mounted) return;
      Navigator.of(context).pop(email ?? widget.email ?? '');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = driverErrorMessage(e, 'Unable to update the password.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration decoration(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD5DEE5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _blue, width: 1.6),
          ),
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Show password' : 'Hide password',
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        );

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Change Password',
        style: TextStyle(fontWeight: FontWeight.w800, color: _titleColor),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 380, maxWidth: 440),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set a new sign-in password for ${widget.driver.displayName}'
                '${widget.email != null ? ' (${widget.email})' : ''}.',
                style: const TextStyle(fontSize: 15, color: _mutedColor),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                enabled: !_saving,
                decoration: decoration('New password'),
                validator: _validatePassword,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                enabled: !_saving,
                decoration: decoration('Confirm password'),
                validator: (v) => v == _password.text ? null : 'Passwords do not match',
                onFieldSubmitted: (_) => _save(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: _red, fontSize: 14)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: _blue,
            minimumSize: const Size(120, 44),
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
              : const Text('Save Password'),
        ),
      ],
    );
  }
}

// ===================================================================
// Everything stored for one driver
// ===================================================================

class _DriverDetailsDialog extends StatelessWidget {
  const _DriverDetailsDialog({required this.driver, required this.email});

  final Driver driver;
  final String? email;

  static String? _number(double? value, String unit) {
    if (value == null) return null;
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
    return '$text $unit';
  }

  @override
  Widget build(BuildContext context) {
    final expired = driver.isLicenseExpired();
    final sex = switch (driver.sex) {
      'M' => 'Male',
      'F' => 'Female',
      _ => driver.sex,
    };

    final personal = <(String, String?)>[
      ('Full name (as on license)', driver.fullName),
      ('Sex', sex),
      ('Date of birth', driver.dateOfBirth == null ? null : _formatDate(driver.dateOfBirth!)),
      ('Nationality', driver.nationality),
      ('Address', driver.address),
      ('Height', _number(driver.heightM, 'm')),
      ('Weight', _number(driver.weightKg, 'kg')),
      ('Blood type', driver.bloodType),
      ('Eye color', driver.eyesColor),
    ];
    final license = <(String, String?)>[
      ('License number', driver.licenseNumber),
      ('Expiry', '${_formatDate(driver.expirationDate)}${expired ? ' (expired)' : ''}'),
      ('DL codes', driver.dlCodes.isEmpty ? null : driver.dlCodes.join(', ')),
      ('Conditions', driver.conditions),
      ('Agency code', driver.agencyCode),
      ('Serial number', driver.serialNumber),
    ];
    final account = <(String, String?)>[
      ('Driver code', driver.driverCode),
      ('Status', driver.isActive ? 'Active' : 'Off Duty'),
      ('Login email', email),
      ('Added on', driver.createdAt == null ? null : _formatDate(driver.createdAt!)),
    ];

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 28, 24, 20),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _blueLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.badge_outlined, color: _blue, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.displayName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _titleColor,
                          ),
                        ),
                        Text(
                          driver.driverCode,
                          style: const TextStyle(fontSize: 15, color: _mutedColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 26, color: Color(0xFF3B4247)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _borderColor),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(34, 24, 34, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _section('Personal Information', personal),
                    const SizedBox(height: 24),
                    _section('Driver’s License', license, highlightRed: expired ? 'Expiry' : null),
                    const SizedBox(height: 24),
                    _section('Roster', account),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<(String, String?)> rows, {String? highlightRed}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _titleColor,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: _borderColor),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 210,
                        child: Text(
                          rows[i].$1,
                          style: const TextStyle(fontSize: 15, color: _mutedColor),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          rows[i].$2 ?? 'Not recorded',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: rows[i].$2 == null ? FontWeight.w400 : FontWeight.w600,
                            color: rows[i].$2 == null
                                ? const Color(0xFFA0AAB0)
                                : rows[i].$1 == highlightRed
                                    ? _red
                                    : _titleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
