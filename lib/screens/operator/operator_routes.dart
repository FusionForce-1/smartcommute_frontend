import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/operator_route.dart';
import '../../services/dio_interceptor.dart';
import '../../services/drivers_service.dart' show driverErrorMessage;
import '../../services/route_services.dart';

// Shared palette for the Routes > Route Management page.
const Color _pageColor = Color(0xFFF4F7F9);
const Color _borderColor = Color(0xFFE1E7EA);
const Color _blue = Color(0xFF2667C2);
const Color _titleColor = Color(0xFF111418);
const Color _mutedColor = Color(0xFF5F6B73);
const Color _green = Color(0xFF198754);
const Color _greenLight = Color(0xFFE4F4E9);
const Color _red = Color(0xFFD93636);
const Color _teal = Color(0xFF2D7D86);
const Color _grey = Color(0xFF8A8F94);
const Color _greyLight = Color(0xFFF0F1F2);
const Color _statsColor = Color(0xFFF5F8FA);

class OperatorRoutes extends StatefulWidget {
  const OperatorRoutes({super.key, this.service});

  /// Injected in tests; defaults to the authenticated app client.
  final RoutesService? service;

  @override
  State<OperatorRoutes> createState() => _OperatorRoutesState();
}

class _OperatorRoutesState extends State<OperatorRoutes> {
  late final RoutesService _service;

  List<OperatorRoute> _routes = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _companyName;
  bool _showCreateForm = false;

  // Routes with a pause/activate/delete request in flight.
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? RoutesService(buildDioClient());
    _loadRoutes();
    _loadCompanyName();
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final routes = await _service.getMyRoutes();
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = driverErrorMessage(e, 'Unable to load routes.');
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

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? _red : null,
      ),
    );
  }

  Future<void> _onRouteCreated(NewRoute route) async {
    setState(() => _showCreateForm = false);
    _showMessage('${route.code} – ${route.name} was created.');
    await _loadRoutes();
  }

  Future<void> _toggleActive(OperatorRoute route) async {
    final activate = !route.isActive;
    if (!activate && route.vehicleCount > 0) {
      final confirmed = await _confirm(
        title: 'Pause route?',
        message: '${route.code} – ${route.name} has ${route.vehicleCount} '
            '${route.vehicleCount == 1 ? 'vehicle' : 'vehicles'} assigned. '
            'Commuters will no longer see this route until you activate it again.',
        action: 'Pause Route',
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _busy.add(route.id));
    try {
      await _service.setActive(route.id, activate);
      if (!mounted) return;
      setState(() {
        _routes = [
          for (final r in _routes) r.id == route.id ? r.copyWith(isActive: activate) : r,
        ];
      });
      _showMessage('${route.code} is now ${activate ? 'active' : 'paused'}.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        driverErrorMessage(e, 'Unable to ${activate ? 'activate' : 'pause'} route.'),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy.remove(route.id));
    }
  }

  Future<void> _confirmDelete(OperatorRoute route) async {
    final confirmed = await _confirm(
      title: 'Delete route?',
      message: '${route.code} – ${route.name} will be removed permanently. '
          'This cannot be undone.',
      action: 'Delete',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy.add(route.id));
    try {
      await _service.deleteRoute(route.id);
      if (!mounted) return;
      setState(() => _routes = _routes.where((r) => r.id != route.id).toList());
      _showMessage('${route.code} – ${route.name} was deleted.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(driverErrorMessage(e, 'Unable to delete route.'), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(route.id));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, color: _titleColor),
        ),
        content: Text(message, style: const TextStyle(color: _mutedColor, fontSize: 15)),
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
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true;
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
            child: RefreshIndicator(
              onRefresh: _loadRoutes,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(40, 36, 38, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildStats(),
                    if (_showCreateForm) ...[
                      const SizedBox(height: 16),
                      _CreateRouteCard(service: _service, onCreated: _onRouteCreated),
                    ],
                    const SizedBox(height: 16),
                    _buildRoutes(),
                  ],
                ),
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
              'Route Management',
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
                'Transit Routes',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _titleColor,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Manage service paths, fares, assigned vehicles, and availability.',
                style: TextStyle(fontSize: 16.5, color: _mutedColor),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _showCreateForm = !_showCreateForm),
            icon: Icon(_showCreateForm ? Icons.close : Icons.add, size: 24),
            label: Text(_showCreateForm ? 'Cancel' : 'Add Route'),
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

  Widget _buildStats() {
    final loaded = !_isLoading && _errorMessage == null;
    String value(int Function() count) => loaded ? '${count()}' : '—';

    final cards = [
      _statCard('Total Routes', value(() => _routes.length), _titleColor),
      _statCard(
        'Active Routes',
        value(() => _routes.where((r) => r.isActive).length),
        _green,
      ),
      _statCard(
        'Assigned Vehicles',
        value(() => _routes.fold(0, (sum, r) => sum + r.vehicleCount)),
        _blue,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              for (final card in cards)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: card),
            ],
          );
        }
        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _statCard(String label, String value, Color valueColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: _mutedColor)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutes() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) return _buildErrorState();
    if (_routes.isEmpty) return _buildEmptyState();

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final columns = constraints.maxWidth >= 900 ? 2 : 1;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final route in _routes)
              SizedBox(
                width: width,
                child: _RouteCard(
                  route: route,
                  busy: _busy.contains(route.id),
                  onToggle: () => _toggleActive(route),
                  onDelete: () => _confirmDelete(route),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildErrorState() {
    return _messageCard(
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
          onPressed: _loadRoutes,
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
    );
  }

  Widget _buildEmptyState() {
    return _messageCard(
      children: const [
        Icon(Icons.alt_route, size: 48, color: Colors.grey),
        SizedBox(height: 12),
        Text(
          'No routes yet. Click Add Route to create your first route.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 15),
        ),
      ],
    );
  }

  Widget _messageCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(children: children),
    );
  }
}

// ===================================================================
// Route card
// ===================================================================

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.busy,
    required this.onToggle,
    required this.onDelete,
  });

  final OperatorRoute route;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTitle(),
          const Divider(height: 1, color: _borderColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTerminals(),
                const SizedBox(height: 14),
                _buildStats(),
                const SizedBox(height: 14),
                _buildToggleButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    final active = route.isActive;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? _blue : _grey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  route.code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _chip(
                      active ? 'Active' : 'Inactive',
                      active ? _green : const Color(0xFF687077),
                      active ? _greenLight : _greyLight,
                    ),
                    if (!route.owned)
                      _chip('Shared', _blue, const Color(0xFFEAF1FA)),
                  ],
                ),
              ],
            ),
          ),
          if (route.owned)
            SizedBox(
              width: 30,
              height: 30,
              child: Tooltip(
                message: 'Delete route',
                child: OutlinedButton(
                  onPressed: busy ? null : onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    side: const BorderSide(color: _red),
                    minimumSize: const Size(30, 30),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Icon(Icons.delete_outline, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildTerminals() {
    const textStyle = TextStyle(fontSize: 15, color: _titleColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _green, width: 1.6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(route.origin ?? '—', style: textStyle)),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(left: 6.3),
          width: 1.4,
          height: 10,
          color: const Color(0xFFCBD3D8),
        ),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 15, color: _red),
            const SizedBox(width: 9),
            Expanded(child: Text(route.destination ?? '—', style: textStyle)),
          ],
        ),
      ],
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _statsColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _stat('Stops', '${route.stopCount}'),
          _stat('Fare', route.fareLabel),
          _stat('Vehicles', '${route.vehicleCount}'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _mutedColor)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _titleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton() {
    if (!route.owned) {
      return const SizedBox(
        height: 44,
        child: Center(
          child: Text(
            'Managed by the operator who created this route',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: _mutedColor),
          ),
        ),
      );
    }

    final pause = route.isActive;
    final color = pause ? _red : _green;
    return OutlinedButton(
      onPressed: busy ? null : onToggle,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: busy ? _borderColor : color),
        minimumSize: const Size.fromHeight(44),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(pause ? 'Pause Route' : 'Activate Route'),
    );
  }
}

// ===================================================================
// Create New Route card
// ===================================================================

class _CreateRouteCard extends StatefulWidget {
  const _CreateRouteCard({required this.service, required this.onCreated});

  final RoutesService service;
  final ValueChanged<NewRoute> onCreated;

  @override
  State<_CreateRouteCard> createState() => _CreateRouteCardState();
}

class _CreateRouteCardState extends State<_CreateRouteCard> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _origin = TextEditingController();
  final _destination = TextEditingController();
  final _fare = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_code, _name, _origin, _destination, _fare]) {
      c.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _origin, _destination, _fare]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged() => setState(() => _error = null);

  double? get _fareValue {
    final fare = double.tryParse(_fare.text.trim());
    return fare != null && fare > 0 ? fare : null;
  }

  bool get _isComplete =>
      _code.text.trim().isNotEmpty &&
      _name.text.trim().isNotEmpty &&
      _origin.text.trim().isNotEmpty &&
      _destination.text.trim().isNotEmpty &&
      _fareValue != null;

  Future<void> _submit() async {
    if (!_isComplete || _saving) return;
    final route = NewRoute(
      code: _code.text.trim().toUpperCase(),
      name: _name.text.trim(),
      origin: _origin.text.trim(),
      destination: _destination.text.trim(),
      baseFare: _fareValue!,
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.createRoute(route);
      if (!mounted) return;
      widget.onCreated(route);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = driverErrorMessage(e, 'Unable to create route.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeField = _field(
      label: 'Route Code',
      controller: _code,
      hint: 'e.g. J05',
      capitalization: TextCapitalization.characters,
      formatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
        LengthLimitingTextInputFormatter(10),
      ],
    );
    final nameField = _field(
      label: 'Route Name',
      controller: _name,
      hint: 'e.g. Talamban – Pier 1',
      formatters: [LengthLimitingTextInputFormatter(80)],
    );
    final originField = _field(
      label: 'Origin',
      controller: _origin,
      hint: 'Starting terminal',
      formatters: [LengthLimitingTextInputFormatter(80)],
    );
    final destinationField = _field(
      label: 'Destination',
      controller: _destination,
      hint: 'End terminal',
      formatters: [LengthLimitingTextInputFormatter(80)],
    );
    final fareField = _field(
      label: 'Base Fare (₱)',
      controller: _fare,
      hint: '13',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      formatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,4}(\.\d{0,2})?'))],
      onSubmitted: (_) => _submit(),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _teal.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create New Route',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'New routes start inactive until you are ready to begin service.',
            style: TextStyle(fontSize: 13, color: _mutedColor),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 600;
              Widget pair(Widget a, Widget b) => twoColumns
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: a),
                        const SizedBox(width: 12),
                        Expanded(child: b),
                      ],
                    )
                  : Column(children: [a, const SizedBox(height: 14), b]);
              return Column(
                children: [
                  pair(codeField, nameField),
                  const SizedBox(height: 14),
                  pair(originField, destinationField),
                  const SizedBox(height: 14),
                  pair(fareField, const SizedBox.shrink()),
                ],
              );
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: _red, fontSize: 14)),
          ],
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _isComplete && !_saving ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                disabledBackgroundColor: _blue.withValues(alpha: 0.35),
                disabledForegroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Route'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextCapitalization capitalization = TextCapitalization.words,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    ValueChanged<String>? onSubmitted,
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
          textCapitalization: capitalization,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          onSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 15),
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
