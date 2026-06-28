import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants/api_endpoints.dart';
import 'api_client.dart';

/// Provides the [WebSocketService].
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService(logger: ref.watch(loggerProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// A realtime event pushed from the server (a notification frame).
class RealtimeEvent {
  const RealtimeEvent({
    required this.type,
    required this.payload,
  });

  /// Event type, e.g. `deposit_confirmed`, `order_completed`.
  final String type;

  /// The full decoded notification (id, type, payload, created_at, …).
  final Map<String, dynamic> payload;
}

/// Maintains the realtime WebSocket to the backend notifications hub
/// (`GET /ws/notifications?token=`), forwarding decoded frames to [events].
class WebSocketService {
  WebSocketService({required Logger logger}) : _logger = logger;

  final Logger _logger;
  final StreamController<RealtimeEvent> _controller =
      StreamController<RealtimeEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  bool _connected = false;

  /// Broadcast stream of incoming realtime events.
  Stream<RealtimeEvent> get events => _controller.stream;

  bool get isConnected => _connected;

  /// Opens the realtime connection, authenticating with [token] (passed as a
  /// query param — browsers can't set headers on a WS handshake).
  Future<void> connect({required String token}) async {
    if (_connected) return;
    final uri = Uri.parse(ApiEndpoints.wsNotifications(token));
    _channel = WebSocketChannel.connect(uri);
    _connected = true;
    _logger.d('WebSocketService.connect() -> $uri');

    _sub = _channel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          _controller.add(
            RealtimeEvent(type: json['type'] as String? ?? '', payload: json),
          );
        } catch (e) {
          _logger.w('WebSocketService: failed to decode frame: $e');
        }
      },
      onError: (Object e) {
        _logger.w('WebSocketService: socket error: $e');
        _connected = false;
      },
      onDone: () {
        _connected = false;
      },
      cancelOnError: true,
    );
  }

  /// The hub pushes all of the authenticated user's notifications, so there is
  /// no per-order subscription frame; this is a no-op kept for API stability.
  void subscribeToOrder(String orderId) {}

  Future<void> disconnect() async {
    if (!_connected && _channel == null) return;
    await _sub?.cancel();
    await _channel?.sink.close();
    _sub = null;
    _channel = null;
    _connected = false;
  }

  void dispose() {
    _sub?.cancel();
    _channel?.sink.close();
    _connected = false;
    _controller.close();
  }
}
