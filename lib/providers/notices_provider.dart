// lib/providers/notices_provider.dart
//
// State for the commuter's Notifications screen: the notices operators sent
// about routes they saved or rode, the selected filter (asked of the server,
// so paging stays right), paging, and read / unread (saved on the backend).
// [checkForNew] looks at the unread count — on a timer while the app is in
// front ([startPolling]) and when it comes back — and reloads when it grew.
// Guests have no inbox, so nothing is fetched for them.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/commuter_notice.dart';
import '../services/api_error.dart';
import '../services/notices_service.dart';
import 'load_state.dart';

class NoticesProvider extends ChangeNotifier {
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
  int _generation = 0;   // bumped by each load; older answers are dropped
  Timer? _poll;
  bool _disposed = false;

  LoadState get state => _state;
  List<CommuterNotice> get notices => _notices;
  NoticeFilter get filter => _filter;
  String? get errorMessage => _errorMessage;

  /// Unread across every category, not just the filtered list.
  int get unreadCount => _unreadCount;
  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;

  /// First call shows a spinner; later calls (pull to refresh, new notices)
  /// keep the current list on screen if they fail.
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

  /// The next page of older notices.
  Future<void> loadMore() async {
    if (isGuest || !_hasMore || _loadingMore) return;
    final generation = _generation;
    _loadingMore = true;
    _notify();
    try {
      final page = await _service.inbox(category: _filter.category, skip: _notices.length, limit: pageSize);
      if (generation == _generation) {
        // A notice that arrived meanwhile shifts the pages: skip repeats.
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

  void setFilter(NoticeFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    _notices = const [];
    _hasMore = false;
    unawaited(load());
  }

  /// Reloads if the unread count went up (a new notice); cheap enough to poll.
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
      // Try again next time.
    }
  }

  void startPolling() {
    if (isGuest) return;
    _poll?.cancel();
    _poll = Timer.periodic(pollInterval, (_) => checkForNew());
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  /// Marks one notice read right away; restores it if the backend refuses.
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

  /// Returns an error message, or null on success.
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

  void _replace(String id, CommuterNotice notice) {
    _notices = [for (final n in _notices) n.id == id ? notice : n];
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
