// lib/providers/alerts_provider.dart
//
// State for the commuter's Notifications screen: the alert feed, the
// selected filter, and read / unread (saved per commuter on the backend).
// Guests see the public alerts with no read state.

import 'package:flutter/foundation.dart';

import '../models/commuter_alert.dart';
import '../services/alerts_service.dart';
import '../services/api_error.dart';
import 'load_state.dart';

class AlertsProvider extends ChangeNotifier {
  AlertsProvider({required AlertsService service, required this.isGuest}) : _service = service;

  final AlertsService _service;
  final bool isGuest;

  LoadState _state = LoadState.idle;
  List<CommuterAlert> _alerts = const [];
  AlertFilter _filter = AlertFilter.all;
  String? _errorMessage;
  bool _disposed = false;

  LoadState get state => _state;
  List<CommuterAlert> get alerts => _alerts;
  AlertFilter get filter => _filter;
  String? get errorMessage => _errorMessage;

  List<CommuterAlert> get visibleAlerts => _alerts.where(_filter.matches).toList();

  /// Guests have no read state, so nothing counts as unread for them.
  bool get tracksReadState => !isGuest;

  int get unreadCount => tracksReadState ? _alerts.where((a) => !a.isRead).length : 0;

  /// First call shows a spinner; later calls (pull to refresh) keep the
  /// current list on screen if they fail.
  Future<void> load() async {
    if (_state == LoadState.loading) return;
    final firstLoad = _alerts.isEmpty;
    if (firstLoad) _state = LoadState.loading;
    _errorMessage = null;
    _notify();

    try {
      _alerts = await _service.feed(isGuest: isGuest);
      _state = LoadState.ready;
    } catch (e) {
      _errorMessage = apiErrorMessage(e);
      _state = firstLoad ? LoadState.error : LoadState.ready;
    }
    _notify();
  }

  void setFilter(AlertFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    _notify();
  }

  /// Marks one alert read right away; restores it if the backend refuses.
  Future<void> markRead(CommuterAlert alert) async {
    if (!tracksReadState || alert.isRead) return;
    _replace(alert.id, alert.markedRead());
    try {
      await _service.markRead(alert.id);
    } catch (_) {
      _replace(alert.id, alert);
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> markAllRead() async {
    if (unreadCount == 0) return null;
    final before = _alerts;
    _alerts = [for (final a in _alerts) a.markedRead()];
    _notify();
    try {
      await _service.markAllRead();
      return null;
    } catch (e) {
      _alerts = before;
      _notify();
      return apiErrorMessage(e);
    }
  }

  void _replace(String id, CommuterAlert alert) {
    _alerts = [for (final a in _alerts) a.id == id ? alert : a];
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
