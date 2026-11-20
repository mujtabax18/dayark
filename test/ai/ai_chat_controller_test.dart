import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/chat/ai_chat_store.dart';
import 'package:metersystem/ai/chat/ai_chat_controller.dart';
import 'package:metersystem/ai/chat/ai_conversation.dart';

class DelayedChatStore extends AiChatStore {
  DelayedChatStore(super.database);

  Future<void> Function()? beforeGetReturns;
  Future<void> Function()? beforeListReturns;

  @override
  Future<AiConversation?> get(String id) async {
    final delay = beforeGetReturns;
    beforeGetReturns = null;
    final value = await super.get(id);
    await delay?.call();
    return value;
  }

  @override
  Future<List<AiConversation>> list({
    String query = '',
    bool archived = false,
    String? folder,
    bool summaries = false,
  }) async {
    final delay = beforeListReturns;
    beforeListReturns = null;
    final value = await super.list(
      query: query,
      archived: archived,
      folder: folder,
      summaries: summaries,
    );
    await delay?.call();
    return value;
  }
}

void main() {
  late DelayedChatStore store;
  late AiChatController chat;
  final histories = <List<AiMessage>>[], profiles = <String?>[];
  var fail = false, hang = false;
  late Completer<void> started;
  setUp(() {
    store = DelayedChatStore(AiChatDatabase(NativeDatabase.memory()));
    histories.clear();
    profiles.clear();
    fail = false;
    hang = false;
    started = Completer<void>();
    chat = AiChatController(
      store: store,
      engine:
          ({
            required message,
            required history,
            required profileId,
            required cancellationToken,
          }) async* {
            histories.add(history.toList());
            profiles.add(profileId);
            yield const AiStreamEvent.activity(
              thinking: 'Checking the question',
            );
            yield const AiStreamEvent.delta('Hello ');
            if (!started.isCompleted) started.complete();
            if (hang) {
              await cancellationToken.whenCancelled;
              cancellationToken.throwIfCancelled();
            }
            if (fail) {
              yield const AiStreamEvent.activity(
                thinking: 'Synthetic hidden reasoning',
                diagnostic: 'Finish reason: length',
              );
              throw const AiException(AiErrorCode.network, 'Network failed.');
            }
            yield const AiStreamEvent.delta('اردو');
            yield AiStreamEvent.completed(
              AiResponse(
                selection: AiModelSelection(
                  providerId: profileId!,
                  modelId: 'model',
                ),
                message: AiMessage(role: AiRole.assistant, text: 'Hello اردو'),
              ),
            );
          },
    );
  });
  tearDown(() async {
    chat.dispose();
    await store.close();
  });
  AiMessage user(String text) => AiMessage(role: AiRole.user, text: text);
  test(
    'complete local thoughts are retained without entering answer history',
    () async {
      chat.dispose();
      final thoughts = '**Thinking** ${'a long model thought ' * 5000}';
      final captured = <List<AiMessage>>[];
      chat = AiChatController(
        store: store,
        engine:
            ({
              required message,
              required history,
              required profileId,
              required cancellationToken,
            }) async* {
              captured.add(history.toList());
              yield AiStreamEvent.activity(thinking: thoughts);
              yield AiStreamEvent.completed(
                AiResponse(
                  selection: AiModelSelection(
                    providerId: 'local',
                    modelId: 'small',
                  ),
                  message: AiMessage(role: AiRole.assistant, text: ''),
                  thinkingOnly: true,
                ),
              );
            },
      );
      await chat.send(
        AiMessage(role: AiRole.user, text: 'Question one'),
        profileId: 'local',
      );
      expect(
        (await store.get(chat.active!.id))!.messages.last.thinking,
        thoughts,
      );
      await chat.send(
        AiMessage(role: AiRole.user, text: 'Question two'),
        profileId: 'local',
      );
      expect(captured.last.map((m) => m.text), ['Question one']);
      expect(chat.active!.messages.last.state, AiChatMessageState.complete);
    },
  );

  test('a delayed selection cannot reopen a chat after New chat', () async {
    await chat.send(user('First'), profileId: 'offline');
    final id = chat.active!.id;
    final reading = Completer<void>(), release = Completer<void>();
    store.beforeGetReturns = () async {
      reading.complete();
      await release.future;
    };
    final selecting = chat.select(id);
    await reading.future;
    chat.newChat();
    release.complete();
    await selecting;
    expect(chat.active, isNull);
  });

  test(
    'the latest selection wins when database reads finish out of order',
    () async {
      await chat.send(user('First'), profileId: 'offline');
      final first = chat.active!.id;
      chat.newChat();
      await chat.send(user('Second'), profileId: 'offline');
      final second = chat.active!.id;
      final reading = Completer<void>(), release = Completer<void>();
      store.beforeGetReturns = () async {
        reading.complete();
        await release.future;
      };
      final selecting = chat.select(first);
      await reading.future;
      await chat.select(second);
      release.complete();
      await selecting;
      expect(chat.active!.id, second);
    },
  );

  test('a delayed refresh cannot replace an active streaming turn', () async {
    await chat.send(user('First'), profileId: 'offline');
    final reading = Completer<void>(), release = Completer<void>();
    store.beforeGetReturns = () async {
      reading.complete();
      await release.future;
    };
    final refreshing = chat.refresh();
    await reading.future;
    hang = true;
    started = Completer<void>();
    final sending = chat.send(user('Second'), profileId: 'offline');
    await started.future;
    release.complete();
    await refreshing;
    expect(chat.active!.messages, hasLength(4));
    expect(chat.active!.messages.last.message.text, 'Hello ');
    chat.stop();
    await sending;
    final saved = (await store.get(chat.active!.id))!;
    expect(saved.messages, hasLength(4));
    expect(saved.messages[2].message.text, 'Second');
    expect(saved.messages.last.state, AiChatMessageState.stopped);
  });

  test('a delayed search cannot replace results for a newer query', () async {
    await chat.send(user('First'), profileId: 'offline');
    chat.newChat();
    await chat.send(user('Second'), profileId: 'offline');
    final reading = Completer<void>(), release = Completer<void>();
    store.beforeListReturns = () async {
      reading.complete();
      await release.future;
    };
    chat.query = 'First';
    final refreshing = chat.refresh();
    await reading.future;
    chat.query = 'Second';
    await chat.refresh();
    release.complete();
    await refreshing;
    expect(chat.conversations.single.title, 'Second');
  });

  test(
    'conversation persists final messages and model switching keeps history',
    () async {
      await chat.send(user('First'), profileId: 'offline');
      expect(chat.active!.messages.last.state, AiChatMessageState.complete);
      await chat.send(user('Second'), profileId: 'online');
      expect(profiles, ['offline', 'online']);
      expect(histories.last.map((m) => m.text), ['First', 'Hello اردو']);
      expect((await store.get(chat.active!.id))!.messages, hasLength(4));
    },
  );
  test('failed partial response is marked and retry replaces it without duplicate user messages', () async {
    fail = true;
    await chat.send(user('Question'), profileId: 'online');
    expect(chat.active!.messages.last.state, AiChatMessageState.failed);
    expect(chat.active!.messages.last.message.text, 'Hello ');
    expect(
      chat.active!.messages.last.diagnostics,
      allOf(contains('Synthetic hidden reasoning'), contains('Hello')),
    );
    fail = false;
    await chat.send(user('Question'), profileId: 'online', retryUserIndex: 0);
    expect(chat.active!.messages, hasLength(2));
    expect(histories.last, isEmpty);
    expect(chat.active!.messages.last.state, AiChatMessageState.complete);
  });
  test('stop persists interrupted output; editing an earlier user prunes later context', () async {
    hang = true;
    final pending = chat.send(user('Original'), profileId: 'offline');
    await started.future;
    expect(chat.thinkingText, 'Checking the question');
    expect(chat.activity, 'Generating response…');
    expect(chat.busy, isTrue);
    chat.stop();
    await pending;
    expect(chat.active!.messages.last.state, AiChatMessageState.stopped);
    hang = false;
    await chat.send(user('Edited'), profileId: 'offline', retryUserIndex: 0);
    expect(chat.active!.messages.first.message.text, 'Edited');
    expect(histories.last, isEmpty);
  });
  test(
    'interrupted persisted messages recover without restarting paid generation',
    () async {
      final c = await store.save(
        AiConversation(
          id: 'interrupted',
          title: 'Interrupted',
          updatedAt: DateTime.now(),
          messages: [
            AiChatMessage(
              id: 'pending',
              message: AiMessage(role: AiRole.assistant, text: 'Partial'),
              createdAt: DateTime.now(),
              state: AiChatMessageState.pending,
            ),
          ],
        ),
      );
      await chat.select(c.id);
      expect(chat.active!.messages.single.state, AiChatMessageState.stopped);
      expect(profiles, isEmpty);
    },
  );
}
