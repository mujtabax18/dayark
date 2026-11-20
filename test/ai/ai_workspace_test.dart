import 'dart:async';
import 'dart:typed_data';

import 'package:metersystem/ai/core/ai_document_cache.dart';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:llamadart/llamadart.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/chat/ai_chat_controller.dart';
import 'package:metersystem/ai/chat/ai_chat_store.dart';
import 'package:metersystem/ai/chat/ai_conversation.dart';
import 'package:metersystem/ai/chat/ai_generation_state.dart';
import 'package:metersystem/ai/chat/ai_workspace_store.dart';
import 'package:metersystem/ai/performance/performance_profile.dart';
import 'package:metersystem/ai/providers/offline/llamadart_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('profiles preserve instructions and use smaller mobile budgets', () {
    final current = AiSettings(customInstructions: 'Use Urdu', temperature: .4);
    final fast = AiPerformanceProfile.fast.apply(current, mobile: true);
    expect(fast.contextWindowTokens, 2048);
    expect(fast.maxOutputTokens, 256);
    expect(fast.thinking, false);
    expect(fast.customInstructions, 'Use Urdu');
    expect(fast.temperature, .4);
    expect(AiSettings.fromJson(fast.toJson()).performanceProfile, 'fast');
    expect(
      AiPerformanceProfile.quality
          .apply(current, mobile: false)
          .contextWindowTokens,
      16384,
    );
    expect(
      AiPerformanceProfile.custom.apply(current, mobile: false),
      same(current),
    );
  });
  test(
    'context fitting reserves output and preserves system and latest turn',
    () async {
      LlamaChatMessage text(LlamaChatRole role, String value) =>
          LlamaChatMessage.fromText(role: role, text: value);
      final system = text(LlamaChatRole.system, 'Protected instructions');
      final latest = text(LlamaChatRole.user, 'Latest question');
      final result = await fitLocalChatContext(
        [
          system,
          text(LlamaChatRole.user, 'Old'),
          text(LlamaChatRole.assistant, 'Answer'),
          latest,
        ],
        contextSize: 100,
        outputTokens: 40,
        countTokens: (items) async => items.length == 4 ? 80 : 30,
      );
      expect(result, [system, latest]);
    },
  );
  test('draft cache is bounded and stores device-only layout', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AiWorkspaceStore(await SharedPreferences.getInstance());
    for (var i = 0; i < 25; i++) {
      await store.saveDraft('$i', 'draft $i');
    }
    expect(store.draft('0'), '');
    expect(store.draft('24'), 'draft 24');
    await store.saveDraft('24', '');
    expect(store.draft('24'), '');
    await store.layout(width: 999, collapsed: true, inspector: false);
    expect(store.sidebarWidth, 360);
    expect(store.sidebarCollapsed, true);
    expect(store.inspector, false);
  });
  test(
    'old messages migrate safely and bookmark/version metadata round-trips',
    () {
      final message = AiChatMessage(
        id: 'm',
        message: AiMessage(role: AiRole.assistant, text: 'Answer'),
        createdAt: DateTime.utc(2026),
      );
      final old = message.toJson()
        ..remove('bookmarked')
        ..remove('versions');
      expect(AiChatMessage.fromJson(old).bookmarked, false);
      final saved = AiChatMessage.fromJson(
        message
            .copyWith(
              bookmarked: true,
              note: 'Useful',
              tags: ['flutter'],
              versions: ['First answer'],
            )
            .toJson(),
      );
      expect(saved.bookmarked, true);
      expect(saved.note, 'Useful');
      expect(saved.tags, ['flutter']);
      expect(saved.versions, ['First answer']);
    },
  );

  test('document cache reuses identical content and invalidates edits and eviction', () async {
    final cache = AiDocumentTextCache();
    var extractions = 0;
    Future<String> extract() async => 'Text ${++extractions}';
    expect(await cache.extract(Uint8List.fromList([1, 2]), extract), 'Text 1');
    expect(await cache.extract(Uint8List.fromList([1, 2]), extract), 'Text 1');
    expect(await cache.extract(Uint8List.fromList([1, 3]), extract), 'Text 2');
    for (var i = 4; i < 13; i++) {
      await cache.extract(Uint8List.fromList([i]), extract);
    }
    await cache.extract(Uint8List.fromList([1, 2]), extract);
    expect(extractions, 12);
    cache.clear();
    await cache.extract(Uint8List.fromList([1, 2]), extract);
    expect(extractions, 13);
  });

  test('large context overflow fits whole recent exchanges with logarithmic tokenization', () async {
    final messages = [
      for (var i = 0; i < 500; i++) ...[
        LlamaChatMessage.fromText(
          role: LlamaChatRole.user,
          text: 'Question $i',
        ),
        LlamaChatMessage.fromText(
          role: LlamaChatRole.assistant,
          text: 'Answer $i',
        ),
      ],
      LlamaChatMessage.fromText(role: LlamaChatRole.user, text: 'Latest'),
    ];
    var counts = 0;
    final fitted = await fitLocalChatContext(
      messages,
      contextSize: 100,
      outputTokens: 40,
      countTokens: (candidate) async {
        counts++;
        return candidate.length * 10;
      },
    );
    expect(fitted.last, same(messages.last));
    expect(fitted.first.role, LlamaChatRole.user);
    expect(fitted.length, lessThanOrEqualTo(6));
    expect(counts, lessThan(15));
    expect(messages.length, 1001);
  });

  late AiChatStore store;
  late AiChatController chat;
  late Completer<void> started, release;
  final calls = <String>[];
  setUp(() {
    store = AiChatStore(AiChatDatabase(NativeDatabase.memory()));
    started = Completer<void>();
    release = Completer<void>();
    calls.clear();
    chat = AiChatController(
      store: store,
      engine:
          ({
            required message,
            required history,
            required profileId,
            required cancellationToken,
          }) async* {
            calls.add(message.text);
            yield const AiStreamEvent.delta('Partial');
            if (message.text == 'Hold') {
              started.complete();
              await release.future;
            }
            if (message.text == 'Wait') {
              started.complete();
              await cancellationToken.whenCancelled;
              // Even a late completion from the cancelled engine must be rejected.
              yield const AiStreamEvent.delta('STALE');
            }
            yield AiStreamEvent.completed(
              AiResponse(
                selection: AiModelSelection(
                  providerId: 'test',
                  modelId: 'small',
                ),
                message: AiMessage(
                  role: AiRole.assistant,
                  text: 'Answer to ${message.text}',
                ),
                usage: const AiUsage(inputTokens: 12, outputTokens: 5),
                finishReason: 'length',
              ),
            );
          },
    );
  });
  tearDown(() async {
    chat.dispose();
    await store.close();
  });
  test(
    'redirect waits for cancellation and preserves partial output',
    () async {
      final first = chat.send(
        AiMessage(role: AiRole.user, text: 'Wait'),
        profileId: 'test',
      );
      await started.future;
      await chat.redirect('Be concise', profileId: 'test');
      await first;
      expect(calls, ['Wait', 'Be concise']);
      expect(chat.active!.messages[1].state, AiChatMessageState.stopped);
      expect(chat.active!.messages[1].message.text, 'Partial');
      expect(
        chat.active!.messages.map((m) => m.message.text).join(),
        isNot(contains('STALE')),
      );
      expect(chat.generationState, AiGenerationState.completed);
      expect(chat.active!.messages.last.outputTokens, 5);
    },
  );
  test(
    'queue editing ordering and cancellation do not start parallel inference',
    () async {
      final first = chat.send(
        AiMessage(role: AiRole.user, text: 'Wait'),
        profileId: 'test',
      );
      await started.future;
      chat.enqueue(
        AiQueuedMessage(
          message: AiMessage(role: AiRole.user, text: 'Second'),
          profileId: 'test',
        ),
      );
      chat.enqueue(
        AiQueuedMessage(
          message: AiMessage(role: AiRole.user, text: 'Third'),
          profileId: 'test',
        ),
      );
      chat.moveQueued(1, 0);
      chat.editQueued(0, 'Edited');
      chat.removeQueued(1);
      expect(chat.queue.single.message.text, 'Edited');
      expect(calls, ['Wait']);
      chat.stop();
      await first;
      expect(chat.queue, hasLength(1));
      expect(chat.generationState, AiGenerationState.interrupted);
    },
  );
  test('successful completion drains queued messages in order', () async {
    final first = chat.send(
      AiMessage(role: AiRole.user, text: 'Hold'),
      profileId: 'test',
    );
    await started.future;
    for (final text in ['Second', 'Third']) {
      chat.enqueue(
        AiQueuedMessage(
          message: AiMessage(role: AiRole.user, text: text),
          profileId: 'test',
        ),
      );
    }
    expect(calls, ['Hold']);
    release.complete();
    await first;
    await Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      return chat.busy || chat.queue.isNotEmpty;
    }).timeout(const Duration(seconds: 3));
    expect(calls, ['Hold', 'Second', 'Third']);
    expect(chat.active!.messages, hasLength(6));
  });

  test(
    'regeneration preserves version and branching leaves original intact',
    () async {
      final question = AiMessage(role: AiRole.user, text: 'Question');
      await chat.send(question, profileId: 'test');
      final originalId = chat.active!.id;
      await chat.send(
        AiMessage(role: AiRole.user, text: 'Revised'),
        profileId: 'test',
        retryUserIndex: 0,
      );
      expect(chat.active!.messages.last.versions, ['Answer to Question']);
      await chat.restoreVersion(chat.active!.messages.last.id, 0);
      expect(chat.active!.messages.last.message.text, 'Answer to Question');
      expect(chat.active!.messages.last.versions, ['Answer to Revised']);
      await chat.bookmark(
        chat.active!.messages.last.id,
        note: 'Note',
        tags: ['test'],
      );
      expect((await store.get(originalId))!.messages.last.bookmarked, true);
      await chat.branch(0);
      expect(chat.active!.id, isNot(originalId));
      expect(chat.active!.messages, hasLength(1));
      expect((await store.get(originalId))!.messages, hasLength(2));
    },
  );
}
