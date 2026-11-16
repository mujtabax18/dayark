import 'dart:convert';

import 'ai_chat_store.dart';

class AiChatSyncReply {
  const AiChatSyncReply(this.status, this.body);
  final int status;
  final Map<String, dynamic> body;
}

/// Protocol implementation shared by the pinned-LAN handler and contract tests.
class AiChatSyncExchange {
  const AiChatSyncExchange({required this.store, required this.authorize});
  final AiChatStore store;
  final Future<bool> Function(String deviceId, String token) authorize;
  static const maxBytes = 32 * 1024 * 1024;
  Future<AiChatSyncReply> exchange(Map<String, dynamic> body) async {
    if (!await store.syncEnabled) {
      return const AiChatSyncReply(403, {'error': 'Chat sync is disabled.'});
    }
    final deviceId = body['deviceId'];
    final token = body['token'];
    if (deviceId is! String ||
        token is! String ||
        token.isEmpty ||
        !await authorize(deviceId, token)) {
      return const AiChatSyncReply(403, {
        'error': 'A current paired device is required.',
      });
    }
    try {
      if (utf8.encode(jsonEncode(body)).length > maxBytes) {
        return const AiChatSyncReply(413, {
          'error': 'Shared chat batch is too large.',
        });
      }
      await store.mergeSync(Map<String, dynamic>.from(body['snapshot'] as Map));
      final result = {'snapshot': await store.syncSnapshot()};
      if (utf8.encode(jsonEncode(result)).length > maxBytes) {
        return const AiChatSyncReply(413, {
          'error': 'Shared chat batch is too large.',
        });
      }
      return AiChatSyncReply(200, result);
    } on AiChatSyncLimit {
      return const AiChatSyncReply(413, {
        'error': 'Shared chat batch is too large.',
      });
    } catch (_) {
      return const AiChatSyncReply(400, {
        'error': 'Invalid chat sync snapshot.',
      });
    }
  }
}
