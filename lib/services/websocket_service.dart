// App WebSocket clients

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/env_config.dart';

/// Build WebSocket address
Uri _wsUri(String path) {
  final base = EnvConfig.wsBaseUrl.replaceAll(RegExp(r'/+$'), '');
  return Uri.parse('$base$path');
}

/// Reconnect wait time
Duration _backoff(int attempt) =>
    Duration(seconds: attempt >= 5 ? 30 : 1 << attempt);

/// Live vehicle updates client
class WebSocketService {
  /// Create live client
  WebSocketService({String? url}) : _url = url;

  final String? _url;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  void Function(dynamic message)? _onMessage;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _active = false;

  Stream<dynamic>? get messages => _channel?.stream;

  /// Open live connection
  void connect() {
    _active = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();

    final channel = WebSocketChannel.connect(
      _url != null ? Uri.parse(_url) : _wsUri('/ws/live'),
    );
    _channel = channel;

    channel.ready.then((_) {
      _reconnectAttempt = 0;
    }).catchError((Object error) {
    });

    if (_onMessage != null) _listen(channel);
  }

  /// Set message handler
  void listenForMessages(
    void Function(dynamic message) onMessage,
  ) {
    _onMessage = onMessage;
    final channel = _channel;
    if (channel != null) _listen(channel);
  }

  /// Listen to connection
  void _listen(WebSocketChannel channel) {
    _subscription?.cancel();
    _subscription = channel.stream.listen(
      (message) {
        try {
          _onMessage?.call(message);
        } catch (e) {
          debugPrint('WebSocket: bad frame ($e): $message');
        }
      },
      onError: (error) {
        debugPrint('WebSocket error: $error');
      },
      onDone: () {
        debugPrint('WebSocket connection closed');
        if (identical(channel, _channel)) _scheduleReconnect();
      },
      cancelOnError: false,
    );
  }

  /// Plan next reconnect
  void _scheduleReconnect() {
    if (!_active) return;
    _channel = null;
    final delay = _backoff(_reconnectAttempt++);
    debugPrint('WebSocket reconnecting in ${delay.inSeconds}s');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, connect);
  }

  /// Close live connection
  void disconnect() {
    _active = false;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }
}

enum GpsSessionState { idle, connecting, live, reconnecting, error }

typedef AccessTokenProvider = Future<String?> Function();

/// Phone GPS sharing session
class GpsIngestionSession extends ChangeNotifier {
  /// Create GPS session
  GpsIngestionSession({
    required this.accessToken,
    this.keepaliveInterval = const Duration(seconds: 10),
  });

  final AccessTokenProvider accessToken;

  final Duration keepaliveInterval;

  static const _sessionExpired = 'Session expired';

  static const maxResendAge = Duration(seconds: 30);

  GpsSessionState _state = GpsSessionState.idle;
  String? _vehicleId;
  String? _error;
  Position? _lastFix;
  DateTime? _lastSentAt;

  WebSocketChannel? _channel;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription? _socketSub;
  Timer? _keepaliveTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _active = false;

  GpsSessionState get state => _state;
  String? get vehicleId => _vehicleId;
  String? get error => _error;
  Position? get lastFix => _lastFix;
  bool get isActive => _active;

  /// Start sharing location
  Future<void> start(String vehicleId) async {
    if (_active) await stop();
    await _ensureLocationPermission();

    _active = true;
    _vehicleId = vehicleId;
    _error = null;
    _reconnectAttempt = 0;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      _onFix,
      onError: (Object e) {
        _keepaliveTimer?.cancel();
        _setError('Location stream error: $e');
      },
    );

    _keepaliveTimer = Timer.periodic(keepaliveInterval, (_) => _keepalive());
    await _connect();
  }

  /// Stop sharing location
  Future<void> stop() async {
    _active = false;
    _keepaliveTimer?.cancel();
    _reconnectTimer?.cancel();
    await _positionSub?.cancel();
    await _socketSub?.cancel();
    await _channel?.sink.close();
    _positionSub = null;
    _socketSub = null;
    _channel = null;
    _setState(GpsSessionState.idle);
  }

  /// Check location permission
  Future<void> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location services are turned off.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied.');
    }
  }

  /// Open GPS socket
  Future<void> _connect() async {
    if (!_active || _vehicleId == null) return;
    _setState(_reconnectAttempt == 0
        ? GpsSessionState.connecting
        : GpsSessionState.reconnecting);

    final WebSocketChannel channel;
    try {
      final token = await accessToken();
      if (!_active) return;
      channel = WebSocketChannel.connect(
        _wsUri('/ws/gps/$_vehicleId'),
        protocols: token == null ? null : ['bearer', token],
      );
      await channel.ready;
    } catch (e) {
      _scheduleReconnect('Could not reach GPS server');
      return;
    }
    if (!_active) {
      channel.sink.close();
      return;
    }

    _channel = channel;
    _reconnectAttempt = 0;
    _error = null;
    _setState(GpsSessionState.live);

    _socketSub = channel.stream.listen(
      (_) {},
      onDone: () => _onSocketClosed(channel.closeCode, channel.closeReason),
      onError: (_) => _onSocketClosed(channel.closeCode, channel.closeReason),
      cancelOnError: true,
    );

    _sendLastFix();
  }

  /// Handle socket close
  void _onSocketClosed(int? code, String? reason) {
    _channel = null;
    _socketSub = null;
    if (!_active) return;
    if (code == 1008 && !(reason ?? '').startsWith(_sessionExpired)) {
      _active = false;
      _keepaliveTimer?.cancel();
      _positionSub?.cancel();
      _setError(reason ?? 'The server refused GPS for this vehicle.');
      return;
    }
    _scheduleReconnect('Connection lost');
  }

  /// Plan next reconnect
  void _scheduleReconnect(String reason) {
    if (!_active) return;
    _error = reason;
    final delay = _backoff(_reconnectAttempt++);
    _setState(GpsSessionState.reconnecting);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connect);
  }

  /// Handle new fix
  void _onFix(Position fix) {
    _lastFix = fix;
    _sendLastFix();
  }

  /// Resend if quiet
  void _keepalive() {
    final last = _lastSentAt;
    final fix = _lastFix;
    if (fix == null || !isFresh(fix, DateTime.now())) return;
    if (last == null || DateTime.now().difference(last) >= keepaliveInterval) {
      _sendLastFix();
    }
  }

  /// Fresh enough to resend
  @visibleForTesting
  static bool isFresh(Position fix, DateTime now) =>
      now.toUtc().difference(fix.timestamp.toUtc()) <= maxResendAge;

  /// Send latest fix
  void _sendLastFix() {
    final fix = _lastFix;
    final channel = _channel;
    if (fix == null || channel == null) return;
    channel.sink.add(jsonEncode(encodeFix(fix)));
    _lastSentAt = DateTime.now();
    notifyListeners();
  }

  /// Fix to JSON frame
  @visibleForTesting
  static Map<String, dynamic> encodeFix(Position fix) => {
        'lat': fix.latitude,
        'lng': fix.longitude,
        'spd': fix.speed >= 0 ? double.parse((fix.speed * 3.6).toStringAsFixed(2)) : null,
        'hdg': fix.heading >= 0 ? double.parse(fix.heading.toStringAsFixed(2)) : null,
        'ts': fix.timestamp.toUtc().toIso8601String(),
      };

  /// Change session state
  void _setState(GpsSessionState s) {
    _state = s;
    notifyListeners();
  }

  /// Set error state
  void _setError(String message) {
    _error = message;
    _setState(GpsSessionState.error);
  }

  /// Stop on dispose
  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
