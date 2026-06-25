import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'api_client.dart';

/// Provides the [WebSocketService].
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService(logger: ref.watch(loggerProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// A realtime event pushed from the server (order updates, new messages…).
class RealtimeEvent {
  const RealtimeEvent({
    required this.type,
    required this.payload,
  });

  final String type;
  final Map<String, dynamic> payload;
}

/// Manages a realtime connection for live order events and chat.
///
/// This is a stub: the actual transport (raw WebSocket via the `web_socket_channel`
/// package, or SSE) is wired later. The public surface — connect / events /
/// dispose — is stable so callers can depend on it now.
class WebSocketService {
  WebSocketService({required Logger logger}) : _logger = logger;

  final Logger _logger;
  final StreamController<RealtimeEvent> _controller =
      StreamController<RealtimeEvent>.broadcast();

  bool _connected = false;

  /// Broadcast stream of incoming realtime events.
  Stream<RealtimeEvent> get events => _controller.stream;

  bool get isConnected => _connected;

  /// Opens the realtime connection, authenticating with [token].
  Future<void> connect({required String token}) async {
    if (_connected) return;
    // TODO: Open a WebSocket to the realtime endpoint, authenticate with the
    // bearer token, and forward parsed frames into [_controller].
    _connected = true;
    _logger.d('WebSocketService.connect() — TODO: open socket');
  }

  /// Subscribes to events scoped to a specific order channel.
  void subscribeToOrder(String orderId) {
    // TODO: Send a subscription frame for `order:$orderId`.
    _logger.d('WebSocketService.subscribeToOrder($orderId) — TODO');
  }

  Future<void> disconnect() async {
    if (!_connected) return;
    // TODO: Close the underlying socket.
    _connected = false;
  }

  void dispose() {
    _connected = false;
    _controller.close();
  }
}
