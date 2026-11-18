// Notices provider
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/commuter_notice.dart';
import '../services/api_error.dart';
import '../services/notices_service.dart';
import 'load_state.dart';

/// Notices provider
class NoticesProvider extends ChangeNotifier {
  /// Create notices
  NoticesProvider({
    required NoticesService service,
    required this.isGuest,
    this.pageSize = 50,
    this.pollInterval = const Duration(seconds: 60),
  }) : _service = service;

  final NoticesService _service;
  final bool isGuest;
  final int pageSize;
  final Duration pollInterval;

  LoadState _state = LoadState.idle;
  List<CommuterNotice> _notices = const [];
  NoticeFilter _filter = NoticeFilter.all;
  String? _errorMessage;
  int _unreadCount = 0;
  bool _hasMore = false;
  bool _loadingMore = false;
  int _generation = 0;
  Timer? _poll;
  bool _disposed = false;

  LoadState get state => _state;
  List<CommuterNotice> get notices => _notices;
  NoticeFilter get filter => _filter;
  String? get errorMessage => _errorMessage;

  int get unreadCount => _unreadCount;
  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;

  /// Load notices
  Future<void> load() async {
    if (isGuest) {
      _state = LoadState.ready;
      _notify();
      return;
    }
    final generation = ++_generation;
    final firstLoad = _notices.isEmpty;
    if (firstLoad) _state = LoadState.loading;
    _errorMessage = null;
    _notify();

    try {
      final results = await Future.wait([
        _service.inbox(category: _filter.category, limit: pageSize),
        _service.unreadCount(),
      ]);
      if (generation != _generation) return;
      _notices = results[0] as List<CommuterNotice>;
      _unreadCount = results[1] as int;
      _hasMore = _notices.length == pageSize;
      _state = LoadState.ready;
    } catch (e) {
      if (generation != _generation) return;
      _errorMessage = apiErrorMessage(e);
      _state = firstLoad ? LoadState.error : LoadState.ready;
    }
    _notify();
  }

  /// Load more
  Future<void> loadMore() async {
    if (isGuest || !_hasMore || _loadingMore) return;
    final generation = _generation;
    _loadingMore = true;
    _notify();
    try {
      final page = await _service.inbox(category: _filter.category, skip: _notices.length, limit: pageSize);
      if (generation == _generation) {
        final known = {for (final n in _notices) n.id};
        _notices = [..._notices, ...page.where((n) => !known.contains(n.id))];
        _hasMore = page.length == pageSize;
      }
    } catch (e) {
      _errorMessage = apiErrorMessage(e);
    } finally {
      _loadingMore = false;
      _notify();
    }
  }

  /// Set filter
  void setFilter(NoticeFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    _notices = const [];
    _hasMore = false;
    unawaited(load());
  }

  /// Check for new
  Future<void> checkForNew() async {
    if (isGuest) return;
    try {
      final count = await _service.unreadCount();
      if (count > _unreadCount) {
        await load();
      } else if (count != _unreadCount) {
        _unreadCount = count;
        _notify();
      }
    } catch (_) {
    }
  }

  /// Start polling
  void startPolling() {
    if (isGuest) return;
    _poll?.cancel();
    _poll = Timer.periodic(pollInterval, (_) => checkForNew());
  }

  /// Stop polling
  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  /// Mark read
  Future<void> markRead(CommuterNotice notice) async {
    if (isGuest || notice.isRead) return;
    _replace(notice.id, notice.markedRead());
    _unreadCount = max(0, _unreadCount - 1);
    _notify();
    try {
      await _service.markRead(notice.id);
    } catch (_) {
      _replace(notice.id, notice);
      _unreadCount++;
      _notify();
    }
  }

  /// Mark all read
  Future<String?> markAllRead() async {
    if (isGuest || _unreadCount == 0) return null;
    final before = _notices;
    final beforeCount = _unreadCount;
    _notices = [for (final n in _notices) n.markedRead()];
    _unreadCount = 0;
    _notify();
    try {
      await _service.markAllRead();
      return null;
    } catch (e) {
      _notices = before;
      _unreadCount = beforeCount;
      _notify();
      return apiErrorMessage(e);
    }
  }

  /// Notices replace
  void _replace(String id, CommuterNotice notice) {
    _notices = [for (final n in _notices) n.id == id ? notice : n];
  }

  /// Notify notices
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Clean up resources
  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
