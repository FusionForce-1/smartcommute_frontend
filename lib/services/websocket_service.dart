// lib/services/websocket_service.dart
//
// Two WebSocket clients, matching the backend's two GPS sockets:
//
//   WebSocketService     — commuter side, WSS /ws/live
//     Receives vehicle broadcasts. Reconnects automatically when the
//     connection drops, so the map doesn't silently stop updating.
//
//   GpsIngestionSession  — driver side, WSS /ws/gps/{vehicle_id}
//     The driver's phone as a backup for the jeep's tracker: it streams
//     during a shift, and the backend uses its fixes only while the tracker
//     is offline. Frames are JSON {"lat","lng","spd","hdg","ts"}: spd in
//     km/h, hdg in degrees from north, ts the device fix time (ISO 8601 UTC).
//
// The driver's access token goes in the subprotocols ("bearer", <token>):
// browsers can't set headers on a WebSocket. Tokens last 15 minutes, so
// when the backend ends the session for an expired token the driver
// session reconnects with a fresh one.
//
// The backend watchdog marks a vehicle "signal_lost" after 30 s without a
// frame and re-arms once frames resume. A parked vehicle's GPS stream goes
// quiet (distance filter), so the driver session re-sends the last fix on
// a keepalive timer to avoid false signal-lost alerts.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/env_config.dart';

Uri _wsUri(String path) {
  final base = EnvConfig.wsBaseUrl.replaceAll(RegExp(r'/+$'), '');
  return Uri.parse('$base$path');
}

/// Exponential backoff: 1, 2, 4, 8, 16, then 30 s max.
Duration _backoff(int attempt) =>
    Duration(seconds: attempt >= 5 ? 30 : 1 << attempt);

// =================================================================
// COMMUTER — live vehicle broadcast
// =================================================================

class WebSocketService {
  WebSocketService({String? url}) : _url = url;

  final String? _url; // defaults to WS_BASE_URL + /ws/live

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  void Function(dynamic message)? _onMessage;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _active = false;

  Stream<dynamic>? get messages => _channel?.stream;

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
      // Failure is also delivered through the stream's onError/onDone,
      // which schedules the reconnect.
    });

    // Re-attach the listener after a reconnect.
    if (_onMessage != null) _listen(channel);
  }

  void listenForMessages(
    void Function(dynamic message) onMessage,
  ) {
    _onMessage = onMessage;
    final channel = _channel;
    if (channel != null) _listen(channel);
  }

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

  void _scheduleReconnect() {
    if (!_active) return;
    _channel = null;
    final delay = _backoff(_reconnectAttempt++);
    debugPrint('WebSocket reconnecting in ${delay.inSeconds}s');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, connect);
  }

  void disconnect() {
    _active = false;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }
}

// =================================================================
// DRIVER — GPS ingestion
// =================================================================

enum GpsSessionState { idle, connecting, live, reconnecting, error }

/// Returns a current (refreshed if needed) access token, or null.
typedef AccessTokenProvider = Future<String?> Function();

class GpsIngestionSession extends ChangeNotifier {
  GpsIngestionSession({
    required this.accessToken,
    this.keepaliveInterval = const Duration(seconds: 10),
  });

  final AccessTokenProvider accessToken;

  /// Must stay well under the backend's 30 s watchdog.
  final Duration keepaliveInterval;

  /// Close reason the backend sends when the access token runs out.
  static const _sessionExpired = 'Session expired';

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

  /// Starts streaming this device's location for [vehicleId].
  /// Throws if location permission is denied or services are off.
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
        distanceFilter: 5, // metres
      ),
    ).listen(
      _onFix,
      onError: (Object e) => _setError('Location stream error: $e'),
    );

    _keepaliveTimer = Timer.periodic(keepaliveInterval, (_) => _keepalive());
    await _connect();
  }

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
      (_) {}, // server doesn't send anything on this socket
      onDone: () => _onSocketClosed(channel.closeCode, channel.closeReason),
      onError: (_) => _onSocketClosed(channel.closeCode, channel.closeReason),
      cancelOnError: true,
    );

    // Push the latest fix right away so the map updates on (re)connect.
    _sendLastFix();
  }

  void _onSocketClosed(int? code, String? reason) {
    _channel = null;
    _socketSub = null;
    if (!_active) return;
    // 1008 = the backend refused this session. An expired token is fixed by
    // reconnecting (with a fresh one); any other refusal won't change.
    if (code == 1008 && !(reason ?? '').startsWith(_sessionExpired)) {
      _active = false;
      _keepaliveTimer?.cancel();
      _positionSub?.cancel();
      _setError(reason ?? 'The server refused GPS for this vehicle.');
      return;
    }
    _scheduleReconnect('Connection lost');
  }

  void _scheduleReconnect(String reason) {
    if (!_active) return;
    _error = reason;
    final delay = _backoff(_reconnectAttempt++);
    _setState(GpsSessionState.reconnecting);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connect);
  }

  void _onFix(Position fix) {
    _lastFix = fix;
    _sendLastFix();
  }

  void _keepalive() {
    final last = _lastSentAt;
    if (last == null || DateTime.now().difference(last) >= keepaliveInterval) {
      _sendLastFix();
    }
  }

  void _sendLastFix() {
    final fix = _lastFix;
    final channel = _channel;
    if (fix == null || channel == null) return;
    channel.sink.add(jsonEncode(encodeFix(fix)));
    _lastSentAt = DateTime.now();
    notifyListeners();
  }

  /// JSON frame accepted by the backend's gps_ingestion handler.
  @visibleForTesting
  static Map<String, dynamic> encodeFix(Position fix) => {
        'lat': fix.latitude,
        'lng': fix.longitude,
        // Geolocator reports m/s and uses negative values for "unknown".
        'spd': fix.speed >= 0 ? double.parse((fix.speed * 3.6).toStringAsFixed(2)) : null,
        'hdg': fix.heading >= 0 ? double.parse(fix.heading.toStringAsFixed(2)) : null,
        'ts': fix.timestamp.toUtc().toIso8601String(),
      };

  void _setState(GpsSessionState s) {
    _state = s;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    _setState(GpsSessionState.error);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
