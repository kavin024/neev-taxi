import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';
import 'models.dart';

/// Live ride updates from `/api/v1/ws`.
///
/// The socket is a *signal*, not the source of truth: after every reconnect the
/// app re-fetches the ride so missed events cannot leave stale UI. Reconnection
/// uses capped exponential backoff.
class NeevRealtime {
  NeevRealtime({
    required this.baseUrl,
    required this.accessToken,
    this.onEvent,
    this.onStatus,
  });

  final String baseUrl;
  final String accessToken;
  final void Function(RealtimeEvent event)? onEvent;
  final void Function(RealtimeConnectionStatus status)? onStatus;

  final _events = StreamController<RealtimeEvent>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _disposed = false;
  bool _connecting = false;
  int _attempt = 0;
  String? _rideId;
  RealtimeConnectionStatus _status = RealtimeConnectionStatus.idle;

  Stream<RealtimeEvent> get events => _events.stream;
  RealtimeConnectionStatus get status => _status;
  String? get rideId => _rideId;

  Uri get _uri {
    final http = Uri.parse(baseUrl);
    final scheme = http.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: http.host,
      port: http.hasPort ? http.port : null,
      path: '${http.path.replaceAll(RegExp(r'/$'), '')}/api/v1/ws',
      queryParameters: {'token': accessToken},
    );
  }

  void _setStatus(RealtimeConnectionStatus value) {
    if (_status == value) return;
    _status = value;
    onStatus?.call(value);
  }

  Future<void> connect() async {
    if (_disposed || _connecting || _channel != null) return;
    _connecting = true;
    _setStatus(RealtimeConnectionStatus.connecting);
    _pingTimer?.cancel();
    try {
      final channel = WebSocketChannel.connect(_uri);
      await channel.ready;
      if (_disposed) {
        await channel.sink.close();
        return;
      }
      _channel = channel;
      _attempt = 0;
      _setStatus(RealtimeConnectionStatus.connected);
      if (_rideId != null) subscribe(_rideId!);
      _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        _send({'action': 'ping'});
      });
      _subscription = channel.stream.listen(
        _handle,
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
        cancelOnError: true,
      );
    } catch (error) {
      debugPrint('Neev realtime connect failed: $error');
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _handle(dynamic raw) {
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final event = RealtimeEvent.fromJson(decoded.cast<String, dynamic>());
      if (event.type == 'heartbeat' || event.type == 'pong') return;
      onEvent?.call(event);
      if (!_events.isClosed) _events.add(event);
    } catch (error) {
      debugPrint('Neev realtime bad frame: $error');
    }
  }

  void subscribe(String rideId) {
    _rideId = rideId;
    _send({'action': 'subscribe', 'ride_id': rideId});
  }

  void _send(Map<String, dynamic> message) {
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _pingTimer?.cancel();
    if (_disposed) return;
    _setStatus(RealtimeConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    final delaySeconds = [1, 2, 4, 8, 15, 30][_attempt.clamp(0, 5)];
    _attempt += 1;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), connect);
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _setStatus(RealtimeConnectionStatus.disconnected);
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _events.close();
  }
}

enum RealtimeConnectionStatus { idle, connecting, connected, disconnected }

/// Convenience helper that builds a realtime client from an [ApiClient].
NeevRealtime realtimeFor(
  ApiClient client, {
  void Function(RealtimeEvent event)? onEvent,
  void Function(RealtimeConnectionStatus status)? onStatus,
}) {
  return NeevRealtime(
    baseUrl: client.baseUrl,
    accessToken: client.session.accessToken ?? '',
    onEvent: onEvent,
    onStatus: onStatus,
  );
}
