import 'dart:convert';

import '../chat/ai_chat_store.dart';
import '../core/ai_input_preparation.dart';
import '../models/ai_models.dart';
import '../rag/embedding_provider.dart';
import '../rag/context_builder.dart';
import '../settings/ai_settings.dart';
import '../prompts/prompt_manager.dart';
import 'memory_store.dart';
import 'chat_memory_service.dart';

Future<EmbeddingProvider?> configuredEmbeddings(MemoryManager memory) async {
  final path = await memory.setting('embeddingPath');
  final id = await memory.setting('embeddingId');
  return path == null || path.isEmpty || id == null || id.isEmpty
      ? null
      : LocalEmbeddingProvider(path: path, modelId: id);
}

class MemoryContextService {
  const MemoryContextService(this.memory, {this.chats});
  final MemoryManager memory;
  final AiChatStore? chats;
  Future<AiBuiltContext> build({
    required AiMessage message,
    required Iterable<AiMessage> history,
    required AiSettings settings,
    EmbeddingProvider? embeddings,
    bool deferToRuntime = false,
  }) async {
    final rag = await memory.flag('rag'),
        facts = await memory.flag('memory'),
        indexChats = await memory.flag('indexChats');
    final provider = rag || facts || indexChats
        ? embeddings ?? await configuredEmbeddings(memory)
        : null;
    if (indexChats && chats != null) {
      await ChatMemoryService(memory, chats!).synchronize(embeddings: provider);
    }
    final hits = rag || facts || indexChats
        ? await memory.search(
            message.text,
            embeddings: provider,
            kinds: {
              if (rag) 'document',
              if (facts) 'memory',
              if (indexChats) 'chat',
            },
          )
        : <RetrievalHit>[];
    // Plain local chat retains history for the model tokenizer to trim exactly.
    if (deferToRuntime && hits.isEmpty) {
      return AiBuiltContext(history.toList(), '', const []);
    }
    return const ContextBuilder().build(
      history: history,
      message: message,
      hits: hits,
      contextTokens: settings.contextWindowTokens ?? 4096,
      outputTokens: deferToRuntime ? 0 : settings.maxOutputTokens ?? 1024,
      enforceInputLimit: !deferToRuntime,
      instructionBytes:
          aiAdditionalPromptBytes(settings) +
          (hits.isEmpty
              ? 0
              : utf8.encode(PromptManager.retrievalInstructions).length + 128),
      summarize: await memory.flag('summaries'),
    );
  }
}
