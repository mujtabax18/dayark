import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/chat/ai_chat_store.dart';
import 'package:metersystem/ai/chat/ai_chat_controller.dart';
import 'package:metersystem/ai/chat/ai_conversation.dart';

void main() {
  late AiChatStore store;
  late AiChatController chat;
  final histories = <List<AiMessage>>[], profiles = <String?>[];
  var fail = false, hang = false;
  late Completer<void> started;
  setUp(() {
    store = AiChatStore(AiChatDatabase(NativeDatabase.memory()));
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
            yield const AiStreamEvent.delta('Hello ');
            if (!started.isCompleted) started.complete();
            if (hang) {
              await cancellationToken.whenCancelled;
              cancellationToken.throwIfCancelled();
            }
            if (fail) {
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
