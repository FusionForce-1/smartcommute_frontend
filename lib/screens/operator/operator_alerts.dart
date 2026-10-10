import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/operator_route.dart';
import '../../models/transit_alert.dart';
import '../../services/alerts_service.dart';
import '../../services/dio_interceptor.dart';
import '../../services/drivers_service.dart' show driverErrorMessage;
import '../../services/route_services.dart';

// Shared palette for the Alerts > Transit Alerts page.
const Color _pageColor = Color(0xFFF4F7F9);
const Color _borderColor = Color(0xFFE1E7EA);
const Color _blue = Color(0xFF2667C2);
const Color _blueLight = Color(0xFFEAF1FA);
const Color _titleColor = Color(0xFF111418);
const Color _mutedColor = Color(0xFF5F6B73);
const Color _green = Color(0xFF198754);
const Color _red = Color(0xFFD93636);
const Color _redLight = Color(0xFFFDECEC);
const Color _amber = Color(0xFFD08700);
const Color _amberLight = Color(0xFFFFF4DF);
const Color _teal = Color(0xFF2D7D86);
const Color _resolvedColor = Color(0xFFFAFBFC);

Color _severityColor(AlertSeverity s) => switch (s) {
      AlertSeverity.info => _blue,
      AlertSeverity.warning => _amber,
      AlertSeverity.critical => _red,
    };

Color _severityLight(AlertSeverity s) => switch (s) {
      AlertSeverity.info => _blueLight,
      AlertSeverity.warning => _amberLight,
      AlertSeverity.critical => _redLight,
    };

class OperatorAlerts extends StatefulWidget {
  const OperatorAlerts({super.key, this.alertsService, this.routesService, this.now});

  /// Injected in tests; default to the authenticated app client.
  final AlertsService? alertsService;
  final RoutesService? routesService;

  /// Injected in tests so time labels are stable.
  final DateTime Function()? now;

  @override
  State<OperatorAlerts> createState() => _OperatorAlertsState();
}

class _OperatorAlertsState extends State<OperatorAlerts> {
  late final AlertsService _alerts;
  late final RoutesService _routesService;

  List<TransitAlert> _items = [];
  List<OperatorRoute> _routes = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _companyName;

  // Alerts with a resolve/reopen/delete request in flight.
  final Set<String> _busy = {};

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final dio = (widget.alertsService == null || widget.routesService == null)
        ? buildDioClient()
        : null;
    _alerts = widget.alertsService ?? AlertsService(dio!);
    _routesService = widget.routesService ?? RoutesService(dio!);
    _loadAlerts();
    _loadRoutes();
    _loadCompanyName();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final alerts = await _alerts.getMyAlerts();
      if (!mounted) return;
      setState(() {
        _items = alerts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = driverErrorMessage(e, 'Unable to load alerts.');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRoutes() async {
    try {
      final routes = await _routesService.getMyRoutes();
      if (!mounted) return;
      setState(() => _routes = routes);
    } catch (_) {
      // The route picker just offers "All routes".
    }
  }

  Future<void> _loadCompanyName() async {
    try {
      final profile = await _alerts.getProfile();
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

  void _onPublished(TransitAlert alert) {
    setState(() => _items = [alert, ..._items]);
    _showMessage('"${alert.title}" was published.');
  }

  /// Puts [alert] back in place of the old copy, keeping unresolved first.
  void _replace(TransitAlert alert) {
    final items = [for (final a in _items) a.id == alert.id ? alert : a];
    final open = items.where((a) => !a.isResolved).toList();
    final resolved = items.where((a) => a.isResolved).toList();
    int newestFirst(TransitAlert a, TransitAlert b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
    open.sort(newestFirst);
    resolved.sort(newestFirst);
    setState(() => _items = [...open, ...resolved]);
  }

  Future<void> _toggleResolved(TransitAlert alert) async {
    final resolve = !alert.isResolved;
    setState(() => _busy.add(alert.id));
    try {
      final updated = await _alerts.setResolved(alert.id, resolve);
      if (!mounted) return;
      _replace(updated);
      _showMessage(resolve ? 'Alert marked as resolved.' : 'Alert reopened.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        driverErrorMessage(e, 'Unable to ${resolve ? 'resolve' : 'reopen'} alert.'),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy.remove(alert.id));
    }
  }

  Future<void> _confirmDelete(TransitAlert alert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Delete alert?',
          style: TextStyle(fontWeight: FontWeight.w800, color: _titleColor),
        ),
        content: Text(
          '"${alert.title}" will be removed for commuters and drivers. '
          'This cannot be undone.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy.add(alert.id));
    try {
      await _alerts.deleteAlert(alert.id);
      if (!mounted) return;
      setState(() => _items = _items.where((a) => a.id != alert.id).toList());
      _showMessage('Alert deleted.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(driverErrorMessage(e, 'Unable to delete alert.'), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(alert.id));
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
            child: RefreshIndicator(
              onRefresh: _loadAlerts,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(40, 36, 38, 32),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final form = _CreateAlertCard(
                      service: _alerts,
                      routes: _routes,
                      onPublished: _onPublished,
                    );
                    final list = _buildPublished();
                    if (constraints.maxWidth < 1000) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [form, const SizedBox(height: 24), list],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 9, child: form),
                        const SizedBox(width: 20),
                        Expanded(flex: 11, child: list),
                      ],
                    );
                  },
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
              'Transit Alerts',
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

  Widget _buildPublished() {
    final active = _items.where((a) => !a.isResolved).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Published Alerts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _titleColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLoading
                        ? 'Loading alerts…'
                        : '$active active ${active == 1 ? 'alert' : 'alerts'}',
                    style: const TextStyle(fontSize: 15, color: _mutedColor),
                  ),
                ],
              ),
            ),
            const Tooltip(
              message: 'New alerts are pushed live to connected commuters and drivers.',
              child: _LiveChip(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_errorMessage != null)
          _buildErrorState()
        else if (_items.isEmpty)
          _buildEmptyState()
        else
          for (final alert in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _AlertCard(
                alert: alert,
                now: _now(),
                busy: _busy.contains(alert.id),
                onToggleResolved: () => _toggleResolved(alert),
                onDelete: () => _confirmDelete(alert),
              ),
            ),
      ],
    );
  }

  Widget _buildErrorState() {
    return _messageCard(children: [
      const Icon(Icons.cloud_off_outlined, size: 44, color: _red),
      const SizedBox(height: 12),
      Text(
        _errorMessage!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _red, fontSize: 15),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: _loadAlerts,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Retry'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _blue,
          side: const BorderSide(color: _blue),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]);
  }

  Widget _buildEmptyState() {
    return _messageCard(children: const [
      Icon(Icons.notifications_none, size: 48, color: Colors.grey),
      SizedBox(height: 12),
      Text(
        'No alerts yet. Alerts you publish will appear here.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey, fontSize: 15),
      ),
    ]);
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

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _blueLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_active_outlined, size: 15, color: _blue),
          SizedBox(width: 6),
          Text(
            'Live notifications',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _blue),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// Published alert card
// ===================================================================

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.now,
    required this.busy,
    required this.onToggleResolved,
    required this.onDelete,
  });

  final TransitAlert alert;
  final DateTime now;
  final bool busy;
  final VoidCallback onToggleResolved;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final resolved = alert.isResolved;
    final color = _severityColor(alert.severity);
    final faded = resolved ? 0.6 : 1.0;
    final created = alert.createdAt;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 16),
      decoration: BoxDecoration(
        color: resolved ? _resolvedColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: resolved || alert.severity == AlertSeverity.info
              ? _borderColor
              : color,
          width: resolved ? 1 : 1.3,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: faded,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _severityLight(alert.severity),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.error_outline, size: 19, color: color),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Opacity(
                  opacity: faded,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _chip(alert.severity.label, color, _severityLight(alert.severity)),
                      _chip(alert.routeCode ?? 'All routes', _mutedColor, const Color(0xFFF0F1F2)),
                      if (resolved)
                        const Text(
                          'Resolved',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _green,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  alert.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: resolved ? _mutedColor : _titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  alert.message,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.4,
                    color: resolved ? const Color(0xFF8A969D) : const Color(0xFF3B474E),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: Color(0xFF8A969D)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        created == null ? '' : alertTimeLabel(created, now),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF8A969D)),
                      ),
                    ),
                    TextButton(
                      onPressed: busy ? null : onToggleResolved,
                      style: TextButton.styleFrom(
                        foregroundColor: resolved ? _blue : _green,
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      child: Text(resolved ? 'Reopen alert' : 'Mark as resolved'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete alert',
            onPressed: busy ? null : onDelete,
            icon: const Icon(Icons.delete_outline, size: 20),
            color: _red,
            visualDensity: VisualDensity.compact,
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
}

// ===================================================================
// Create Transit Alert card
// ===================================================================

class _CreateAlertCard extends StatefulWidget {
  const _CreateAlertCard({
    required this.service,
    required this.routes,
    required this.onPublished,
  });

  final AlertsService service;
  final List<OperatorRoute> routes;
  final ValueChanged<TransitAlert> onPublished;

  @override
  State<_CreateAlertCard> createState() => _CreateAlertCardState();
}

class _CreateAlertCardState extends State<_CreateAlertCard> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  AlertSeverity _severity = AlertSeverity.info;
  String? _routeId; // null = all routes

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title.addListener(_onChanged);
    _message.addListener(_onChanged);
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() => _error = null);

  bool get _isComplete =>
      _title.text.trim().isNotEmpty && _message.text.trim().isNotEmpty;

  Future<void> _publish() async {
    if (!_isComplete || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final alert = await widget.service.publish(NewAlert(
        title: _title.text.trim(),
        message: _message.text.trim(),
        severity: _severity,
        routeId: _routeId,
      ));
      if (!mounted) return;
      _title.clear();
      _message.clear();
      setState(() {
        _saving = false;
        _severity = AlertSeverity.info;
        _routeId = null;
      });
      widget.onPublished(alert);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = driverErrorMessage(e, 'Unable to publish alert.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // A route that disappeared from the list falls back to "All routes".
    final routeId = widget.routes.any((r) => r.id == _routeId) ? _routeId : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _blueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.campaign_outlined, size: 20, color: _blue),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Transit Alert',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: _titleColor,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Notify commuters and drivers about service changes.',
                      style: TextStyle(fontSize: 13, color: _mutedColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _label('Alert Title'),
          TextField(
            controller: _title,
            enabled: !_saving,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(100)],
            decoration: _decoration('Short alert heading'),
          ),
          const SizedBox(height: 16),
          _label('Message'),
          TextField(
            controller: _message,
            enabled: !_saving,
            minLines: 4,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(1000)],
            decoration: _decoration('Describe the service update...'),
          ),
          const SizedBox(height: 16),
          _label('Severity'),
          Row(
            children: [
              for (final s in AlertSeverity.values) ...[
                if (s != AlertSeverity.info) const SizedBox(width: 8),
                Expanded(child: _severityButton(s)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _label('Affected Route'),
          DropdownButtonFormField<String?>(
            key: ValueKey(routeId),
            initialValue: routeId,
            isExpanded: true,
            decoration: _decoration(null),
            onChanged: _saving ? null : (value) => setState(() => _routeId = value),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All routes')),
              for (final r in widget.routes)
                DropdownMenuItem<String?>(
                  value: r.id,
                  child: Text('${r.code} – ${r.name}', overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: _red, fontSize: 14)),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isComplete && !_saving ? _publish : null,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_outlined, size: 18),
            label: const Text('Publish Alert'),
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              disabledBackgroundColor: _blue.withValues(alpha: 0.35),
              disabledForegroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _severityButton(AlertSeverity s) {
    final selected = _severity == s;
    final color = _severityColor(s);
    return OutlinedButton(
      onPressed: _saving ? null : () => setState(() => _severity = s),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? color : Colors.white,
        foregroundColor: selected ? Colors.white : color,
        side: BorderSide(color: color),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(s == AlertSeverity.info ? 'Info' : s.label),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _titleColor,
          ),
        ),
      );

  InputDecoration _decoration(String? hint) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9AA5AB), fontSize: 14),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      enabledBorder: border(_teal),
      focusedBorder: border(_teal, 1.8),
      disabledBorder: border(_borderColor),
    );
  }
}
