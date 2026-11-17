import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metersystem/ai/settings/ai_settings_store.dart';
import 'package:metersystem/ai/settings/ai_configured_assistant.dart';
import 'package:metersystem/ai/chat/ai_chat_controller.dart';
import 'package:metersystem/ai/chat/ai_chat_store.dart';
import 'package:metersystem/ai/chat/ai_conversation.dart';
import 'package:metersystem/ai/widgets/ai_response_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('burst stream yields to timers and batches snapshots without losing answer or thoughts', () async {
    final store = AiChatStore(AiChatDatabase(NativeDatabase.memory()));
    const fragment = '**Chunk** اردو 🌱 model output.\n';
    const count = 12000;
    var receiving = false, heartbeats = 0, notifications = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
      if (receiving) heartbeats++;
    });
    final controller = AiChatController(
      store: store,
      engine:
          ({
            required message,
            required history,
            required profileId,
            required cancellationToken,
          }) async* {
            receiving = true;
            for (var i = 0; i < count; i++) {
              cancellationToken.throwIfCancelled();
              yield const AiStreamEvent.activity(thinking: fragment);
              yield const AiStreamEvent.delta(fragment);
            }
            receiving = false;
            yield AiStreamEvent.completed(
              AiResponse(
                selection: AiModelSelection(
                  providerId: 'ollama',
                  modelId: 'qwen',
                ),
                message: AiMessage(
                  role: AiRole.assistant,
                  text: fragment * count,
                ),
              ),
            );
          },
    );
    controller.addListener(() => notifications++);
    try {
      await controller.send(
        AiMessage(role: AiRole.user, text: 'Long reply'),
        profileId: 'ollama',
      );
      expect(
        heartbeats,
        greaterThan(10),
        reason: 'Timers/input must run while a buffered response is being consumed.',
      );
      expect(
        notifications,
        lessThan(240),
        reason: 'No full-message snapshot per token.',
      );
      final saved = (await store.get(controller.active!.id))!.messages.last;
      expect(saved.message.text, fragment * count);
      expect(saved.thinking, fragment * count);
      expect(saved.state, AiChatMessageState.complete);
    } finally {
      timer.cancel();
      controller.dispose();
      await store.close();
    }
  });

  test('large Ollama HTTP burst stays cancellable and preserves Unicode through the real gateway', () async {
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final store = AiChatStore(AiChatDatabase(NativeDatabase.memory()));
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final settings = AiSettingsStore(
      preferences: await SharedPreferences.getInstance(),
    );
    await settings.save(
      AiPreferences(
        profiles: [
          AiProviderProfile(
            id: 'ollama',
            name: 'Ollama',
            kind: AiProviderKind.ollama,
            modelId: 'qwen3.5:2b',
            baseUrl: 'http://127.0.0.1:${server.port}/api/',
          ),
        ],
        selectedProfileId: 'ollama',
        allowOnlineProcessing: true,
      ),
    );
    const fragment = '**Reply** اردو 🌱 data that must not be dropped.\n';
    const count = 6000;
    Map<String, dynamic>? requestBody;
    server.listen((request) async {
      requestBody = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;
      request.response.headers.contentType = ContentType(
        'application',
        'x-ndjson',
      );
      final line = jsonEncode({
        'message': {
          'role': 'assistant',
          'content': fragment,
          'thinking': fragment,
        },
        'done': false,
      });
      request.response.add(
        utf8.encode(
          '${'$line\n' * count}${jsonEncode({'done': true, 'done_reason': 'stop'})}\n',
        ),
      );
      await request.response.close();
    });
    final assistant = AiConfiguredAssistant(settings);
    var events = 0, done = false, heartbeats = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
      if (events > 0 && !done) heartbeats++;
    });
    final controller = AiChatController(
      store: store,
      engine:
          ({
            required message,
            required history,
            required profileId,
            required cancellationToken,
          }) async* {
            await for (final event in assistant.stream(
              message: message,
              history: history,
              profileId: profileId,
              cancellationToken: cancellationToken,
            )) {
              events++;
              if (event.response != null) done = true;
              yield event;
            }
          },
    );
    try {
      await controller.send(
        AiMessage(role: AiRole.user, text: 'Stream a long reply'),
        profileId: 'ollama',
      );
      expect(heartbeats, greaterThan(5));
      expect(events, greaterThanOrEqualTo(count * 2));
      expect(requestBody!['options']['num_predict'], -1);
      final saved = (await store.get(controller.active!.id))!.messages.last;
      expect(saved.message.text, fragment * count);
      expect(saved.thinking, fragment * count);
      expect(saved.state, AiChatMessageState.complete);
    } finally {
      timer.cancel();
      controller.dispose();
      await store.close();
      await server.close(force: true);
      HttpOverrides.global = previousOverrides;
    }
  });

  test(
    'Stop interrupts a hot stream and saves the entire received prefix',
    () async {
      final store = AiChatStore(AiChatDatabase(NativeDatabase.memory()));
      late AiChatController controller;
      var emitted = 0, cancelledAtProvider = false;
      controller = AiChatController(
        store: store,
        engine:
            ({
              required message,
              required history,
              required profileId,
              required cancellationToken,
            }) async* {
              try {
                for (var i = 0; i < 100000; i++) {
                  cancellationToken.throwIfCancelled();
                  if (i == 256) Timer.run(controller.stop);
                  emitted++;
                  yield const AiStreamEvent.delta('fragment\n');
                }
              } finally {
                cancelledAtProvider = cancellationToken.isCancelled;
              }
            },
      );
      try {
        await controller.send(
          AiMessage(role: AiRole.user, text: 'Stop this stream'),
          profileId: 'ollama',
        );
        expect(cancelledAtProvider, isTrue);
        expect(emitted, lessThan(1000));
        final saved = (await store.get(controller.active!.id))!.messages.last;
        expect(saved.state, AiChatMessageState.stopped);
        expect(saved.message.text, isNotEmpty);
        expect(('fragment\n' * emitted).startsWith(saved.message.text), isTrue);
        expect(controller.busy, isFalse);
      } finally {
        controller.dispose();
        await store.close();
      }
    },
  );

  test('Markdown blocks retain Unicode, cache sealed prefixes and carry code fences', () {
    final plain = 'اردو 🌱 text\n' * 10000;
    final blocks = AiMarkdownBlocks()..update(plain);
    expect([for (var i = 0; i < blocks.length; i++) blocks[i]].join(), plain);
    expect(
      [for (var i = 0; i < blocks.length; i++) blocks[i]]
          .every((block) => utf8.decode(utf8.encode(block)) == block),
      isTrue,
    );
    final sealed = blocks[0];
    blocks.update('$plain appended');
    expect(identical(blocks[0], sealed), isTrue);
    final code = AiMarkdownBlocks()
      ..update('```dart\n${'print(1);\n' * 1000}```\n');
    for (var i = 0; i < code.length; i++) {
      expect(code[i], startsWith('```dart\n'));
      expect(code[i].trimRight(), endsWith('```'));
      expect(
        code[i].length,
        lessThanOrEqualTo(AiMarkdownBlocks.blockSize + 40),
      );
    }
  });

  testWidgets('live tail does not measure every preceding Markdown block', (
    tester,
  ) async {
    var renderedImages = 0;
    final text =
        '![marker](https://never-fetch.example/image.png)\n\n${'Useful response text. ' * 10}\n\n' *
        5000;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiResponseText(
            data: text,
            live: true,
            maxHeight: 300,
            imageBuilder: (_, _, _) {
              renderedImages++;
              return const Text('Local marker');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      renderedImages,
      lessThan(100),
      reason:
          'Auto-follow must not parse/layout all 5000 earlier image markers.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'megabyte response builds only visible Markdown blocks and leaves controls interactive',
    (tester) async {
      var stops = 0;
      final theme = ThemeData.light();
      final content = '**Paragraph** with useful text and `code`.\n\n' * 24000;
      Future<void> render(String text) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Column(
                children: [
                  AiResponseText(data: text, maxHeight: 300),
                  TextButton(
                    onPressed: () => stops++,
                    child: const Text('Stop'),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await render(content);
      expect(find.byType(MarkdownBody).evaluate().length, lessThan(12));
      expect(
        tester
            .widgetList<MarkdownBody>(find.byType(MarkdownBody))
            .every(
              (body) => body.data.length <= AiMarkdownBlocks.blockSize + 40,
            ),
        isTrue,
      );
      final first = tester.widget<MarkdownBody>(
        find.byType(MarkdownBody).first,
      );
      await tester.tap(find.text('Stop'));
      await tester.pump();
      expect(stops, 1);
      await render('$content new ending');
      expect(
        identical(
          first,
          tester.widget<MarkdownBody>(find.byType(MarkdownBody).first),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
