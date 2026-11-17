import 'dart:convert';

import '../chat/ai_chat_store.dart';
import '../chat/ai_conversation.dart';
import '../rag/embedding_provider.dart';
import 'memory_store.dart';

/// Reconciles revisions before every retrieval, including remote edits/deletions.
/// Only AI conversation text is indexed; feature databases are never consulted.
class ChatMemoryService {
  const ChatMemoryService(this.memory, this.chats);
  final MemoryManager memory;
  final AiChatStore chats;
  Future<void> synchronize({EmbeddingProvider? embeddings}) async {
    final enabled = await memory.flag('indexChats');
    final current = enabled
        ? [...await chats.list(), ...await chats.list(archived: true)]
        : <AiConversation>[];
    final ids = current.map((c) => 'chat_${c.id}').toSet();
    for (final source in await memory.sources()) {
      if (source.kind == 'chat' && !ids.contains(source.id)) {
        await memory.delete(source.id);
      }
    }
    for (final c in current) {
      if (await memory.flag('excluded_chat_${c.id}')) continue;
      final text = c.messages
          .where(
            (m) =>
                m.state == AiChatMessageState.complete &&
                !m.message.containsPrivateContext,
          )
          .map((m) => '${m.message.role.name}: ${m.message.text}')
          .join('\n\n');
      if (text.trim().isEmpty) {
        await memory.delete('chat_${c.id}');
        continue;
      }
      // Chat DB already limits records. Keep a bounded UTF-8-safe tail for index.
      final runes = text.runes.toList();
      final bounded = String.fromCharCodes(
        runes.skip((runes.length - 200000).clamp(0, runes.length)),
      );
      if (utf8.encode(bounded).length > 1024 * 1024) continue;
      await memory.put(
        id: 'chat_${c.id}',
        title: c.title,
        kind: 'chat',
        text: bounded,
        embeddings: embeddings,
      );
    }
  }
}
