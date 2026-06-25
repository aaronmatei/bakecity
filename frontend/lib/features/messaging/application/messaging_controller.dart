import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../services/api_client.dart';
import '../domain/message.dart';

/// Loads the message thread for an order.
final orderMessagesProvider =
    FutureProvider.family<List<Message>, String>((ref, orderId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>(
    ApiEndpoints.orderMessages(orderId),
  );
  final items =
      (response.data?['data'] ?? response.data?['messages'] ?? []) as List;
  return items
      .map((e) => Message.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Sends messages within an order conversation.
final messagingControllerProvider = Provider<MessagingController>((ref) {
  return MessagingController(ref.read(apiClientProvider));
});

class MessagingController {
  MessagingController(this._api);

  final ApiClient _api;

  /// Posts a new message to an order thread.
  Future<Message> sendMessage({
    required String orderId,
    required String body,
    List<String> attachmentUrls = const [],
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.orderMessages(orderId),
      data: {
        'body': body,
        'attachment_urls': attachmentUrls,
      },
    );
    return Message.fromJson(response.data!);
  }
}
