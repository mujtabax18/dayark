import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/settings/ai_flutter_settings.dart';
import 'package:metersystem/ai/chat/ai_chat_screen.dart';
import 'package:metersystem/ai/chat/ai_chat_controller.dart';
import 'package:metersystem/ai/chat/ai_chat_store.dart';
import 'package:metersystem/ai/chat/ai_conversation.dart';
import 'package:metersystem/screens/navigation/widgets/desktop_navigation_scope.dart';
import 'package:metersystem/utlis/app_router.dart';

class FailingChatStore extends AiChatStore {
  FailingChatStore(super.database);
  @override
  Future<AiConversation> save(
    AiConversation c, {
    int? expectedRevision,
  }) async => throw StateError('Simulated full disk');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AiChatStore chats;
  late AiSettingsStore settings;
  final selected = <String?>[], histories = <List<AiMessage>>[];
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    chats = AiChatStore(AiChatDatabase(NativeDatabase.memory()));
    await chats.deviceId;
    settings = AiSettingsStore(
      preferences: await SharedPreferences.getInstance(),
    );
    await settings.save(
      AiPreferences(
        profiles: [
          AiProviderProfile(
            id: 'first',
            name: 'Local',
            kind: AiProviderKind.offline,
            modelId: 'small',
          ),
          AiProviderProfile(
            id: 'second',
            name: 'Online',
            kind: AiProviderKind.openai,
            modelId: 'gpt-6.1-sol',
          ),
        ],
        selectedProfileId: 'first',
      ),
    );
    selected.clear();
    histories.clear();
  });
  tearDown(() async => chats.close());
  AiChatStream getEngine() =>
      ({
        required message,
        required history,
        required profileId,
        required cancellationToken,
      }) async* {
        selected.add(profileId);
        histories.add(history.toList());
        yield const AiStreamEvent.delta('**Hello** ');
        yield const AiStreamEvent.delta(
          'اردو\n\n```dart\nprint("Hello");\n```\n\n![blocked](https://never-fetch.example/image.png)',
        );
        yield AiStreamEvent.completed(
          AiResponse(
            selection: AiModelSelection(
              providerId: profileId!,
              modelId: profileId == 'first' ? 'small' : 'gpt-6.1-sol',
            ),
            message: AiMessage(
              role: AiRole.assistant,
              text: '**Hello** اردو\n\n```dart\nprint("Hello");\n```\n\n![blocked](https://never-fetch.example/image.png)',
            ),
          ),
        );
      };
  Future<void> open(
    WidgetTester tester, {
    bool mobile = false,
    AiChatStream? engine,
  }) async {
    tester.view.physicalSize = mobile
        ? const Size(390, 844)
        : const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AiChatScreen(
            store: chats,
            settings: settings,
            engine: engine ?? getEngine(),
            sync: () async => 'Test sync complete.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Message DayArk…',
      ),
      text,
    );
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'chat exposes prompts and persists the extra prompt switch on mobile',
    (tester) async {
      await open(tester, mobile: true);
      await tester.tap(find.text('Your instructions'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Keep replies short. Help me plan my DayArk tasks.',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(
        settings.load().settings.customInstructions,
        contains('DayArk tasks'),
      );

      await tester.tap(find.text('View prompts'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Keep replies short.', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(settings.load().settings.sendAdditionalPrompt, isFalse);
      expect(settings.load().profiles, hasLength(2));
      expect(
        settings.load().settings.customInstructions,
        contains('DayArk tasks'),
      );

      await tester.tap(find.text('View prompts'));
      await tester.pumpAndSettle();
      expect(find.textContaining('You are the DayArk assistant'), findsNothing);
      expect(
        find.textContaining('Keep replies short.', findRichText: true),
        findsNothing,
      );
      await tester.tap(find.text('Latest request'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Send a message to see'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('local chat shows live thinking, then streams the answer', (
    tester,
  ) async {
    final finishThinking = Completer<void>();
    await open(
      tester,
      engine:
          ({
            required message,
            required history,
            required profileId,
            required cancellationToken,
          }) async* {
            yield const AiStreamEvent.activity(
              thinking: '**Checking** the question',
            );
            await finishThinking.future;
            yield const AiStreamEvent.delta('Ready');
            yield AiStreamEvent.completed(
              AiResponse(
                selection: AiModelSelection(
                  providerId: profileId!,
                  modelId: 'small',
                ),
                message: AiMessage(role: AiRole.assistant, text: 'Ready'),
              ),
            );
          },
    );
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    expect(find.textContaining('answer quality may be lower'), findsOneWidget);
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Message DayArk…',
      ),
      'Question',
    );
    await tester.tap(find.byTooltip('Send message'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Thinking…'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Checking the question'), findsOneWidget);
    expect(find.text('**Checking** the question'), findsNothing);
    expect(find.text('pending'), findsNothing);
    finishThinking.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Model thinking'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'chat renders Markdown/code safely and switches models without losing conversation',
    (tester) async {
      await open(tester);
      expect(find.byTooltip('Attach files'), findsOneWidget);
      expect(find.byTooltip('Attach images'), findsNothing);
      await send(tester, 'Question one');
      expect(find.byType(MarkdownBody), findsNWidgets(2));
      expect(find.text('[Image: blocked]'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'small'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search models'),
        'online',
      );
      await tester.pumpAndSettle();
      expect(find.text('Local · small'), findsNothing);
      await tester.tap(find.text('Online · gpt-6.1-sol').last);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Attach images'), findsOneWidget);
      await send(tester, 'Question two');
      expect(selected, ['first', 'second']);
      expect(histories.last.first.text, 'Question one');
      expect((await chats.list()).single.messages, hasLength(4));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'mobile chat supports copy, edit/regenerate, rename and opt-in sync',
    (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await open(tester, mobile: true);
      await send(tester, 'Original');
      await tester.tap(find.byTooltip('Copy message').first);
      await tester.pump();
      expect(clipboard, contains('اردو'));
      await tester.ensureVisible(find.byTooltip('Edit message'));
      await tester.tap(find.byTooltip('Edit message'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Edited');
      await tester.tap(find.text('Save and regenerate'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect((await chats.list()).single.messages.first.message.text, 'Edited');
      expect((await chats.list()).single.messages, hasLength(2));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'My chat');
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect((await chats.list()).single.title, 'My chat');
      await tester.tap(find.byTooltip('Chat preferences'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Automatic paired-device sync'));
      await tester.pumpAndSettle();
      expect(await chats.syncEnabled, isTrue);
      expect((await chats.list()).single.shareWithDevices, isTrue);
      await tester.tap(find.text('Sync shared chats now'));
      await tester.pumpAndSettle();
      expect(find.text('Test sync complete.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'creates and pins folders, starts a chat in a folder, moves and pins the chat',
    (tester) async {
      await open(tester);
      Future<void> folder(String name) async {
        await tester.tap(find.byTooltip('New folder'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, name);
        await tester.tap(find.text('Create folder'));
        await tester.pumpAndSettle();
      }

      await folder('Work');
      expect((await chats.folders()).single.name, 'Work');
      await tester.tap(find.byTooltip('Pin folder'));
      await tester.pumpAndSettle();
      expect((await chats.folders()).single.pinned, isTrue);
      await send(tester, 'Folder conversation');
      expect((await chats.list()).single.folder, 'Work');
      expect(
        (await chats.list()).single.messages.last.elapsedMilliseconds,
        isNotNull,
      );
      expect(find.textContaining('response'), findsWidgets);
      await folder('Personal');
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to folder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personal').last);
      await tester.pumpAndSettle();
      expect((await chats.list()).single.folder, 'Personal');
      expect((await chats.list()).single.messages, hasLength(2));
      await tester.tap(find.byTooltip('Chat actions: Folder conversation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pin chat'));
      await tester.pumpAndSettle();
      expect((await chats.list()).single.pinned, isTrue);
      expect((await chats.folders()).first.name, 'Work');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'local draft reaches the model without byte-based context rejection',
    (tester) async {
      await settings.save(
        AiPreferences(
          profiles: settings.load().profiles,
          selectedProfileId: 'first',
          settings: AiSettings(
            contextWindowTokens: 2048,
            maxOutputTokens: 2048,
          ),
        ),
      );
      await open(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Message DayArk…'),
        'hello',
      );
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(selected, ['first']);
      expect(find.text('Input exceeds the model limit'), findsNothing);
      expect((await chats.list()).single.messages.first.message.text, 'hello');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'remote oversized draft is kept, summary is opt-in and reviewed before sending',
    (tester) async {
      await settings.save(
        AiPreferences(
          profiles: settings.load().profiles,
          selectedProfileId: 'second',
          allowOnlineProcessing: true,
        ),
      );
      await open(
        tester,
        engine:
            ({
              required message,
              required history,
              required profileId,
              required cancellationToken,
            }) async* {
              selected.add(profileId);
              yield AiStreamEvent.completed(
                AiResponse(
                  selection: AiModelSelection(
                    providerId: profileId!,
                    modelId: 'small',
                  ),
                  message: AiMessage(
                    role: AiRole.assistant,
                    text: 'A concise summary.',
                  ),
                ),
              );
            },
      );
      final draft = 'Some document facts. ' * 300;
      await tester.enterText(
        find.widgetWithText(TextField, 'Message DayArk…'),
        draft,
      );
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Input exceeds the model limit'), findsOneWidget);
      expect(selected, isEmpty);
      expect(await chats.list(), isEmpty);
      await tester.tap(find.text('Keep draft'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Message DayArk…'),
            )
            .controller!
            .text,
        draft,
      );
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Summarize in parts'));
      await tester.pumpAndSettle();
      expect(find.text('Review shortened prompt'), findsOneWidget);
      expect(await chats.list(), isEmpty);
      await tester.tap(find.text('Use summary'));
      await tester.pumpAndSettle();
      final input = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Message DayArk…'),
      );
      expect(input.controller!.text, contains('A concise summary.'));
      expect(input.controller!.text.length, lessThan(draft.length));
      expect(await chats.list(), isEmpty);
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(
        (await chats.list()).single.messages.first.message.text,
        contains('AI-generated summary'),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'remote summary progress is a compact chat-pane dialog and streams formatted thoughts',
    (tester) async {
      await settings.save(
        AiPreferences(
          profiles: settings.load().profiles,
          selectedProfileId: 'second',
          allowOnlineProcessing: true,
        ),
      );
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final finish = Completer<void>();
      var shellActions = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Row(
              children: [
                SizedBox(
                  width: 240,
                  child: Center(
                    child: TextButton(
                      onPressed: () => shellActions++,
                      child: const Text('Shell action'),
                    ),
                  ),
                ),
                Expanded(
                  child: AiChatScreen(
                    store: chats,
                    settings: settings,
                    engine:
                        ({
                          required message,
                          required history,
                          required profileId,
                          required cancellationToken,
                        }) async* {
                          yield const AiStreamEvent.activity(
                            thinking: '**Reading** the source',
                          );
                          await finish.future;
                          cancellationToken.throwIfCancelled();
                          yield AiStreamEvent.completed(
                            AiResponse(
                              selection: AiModelSelection(
                                providerId: profileId!,
                                modelId: 'small',
                              ),
                              message: AiMessage(
                                role: AiRole.assistant,
                                text: 'A short summary.',
                              ),
                            ),
                          );
                        },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final draft = 'Document facts to summarize. ' * 300;
      await tester.enterText(
        find.widgetWithText(TextField, 'Message DayArk…'),
        draft,
      );
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('I don’t recommend summarizing'),
        findsOneWidget,
      );
      await tester.tap(find.text('Summarize in parts'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Summarizing input'), findsOneWidget);
      expect(find.text('Reading the source'), findsOneWidget);
      expect(find.text('**Reading** the source'), findsNothing);
      final dialog = tester.getRect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byWidgetPredicate(
            (widget) => widget is Material && widget.type == MaterialType.card,
          ),
        ),
      );

      expect(dialog.left, greaterThanOrEqualTo(240));
      expect(dialog.right, lessThanOrEqualTo(1200));
      expect(dialog.width, lessThanOrEqualTo(440));
      expect(dialog.height, lessThanOrEqualTo(400));
      expect(dialog.center.dx, closeTo(720, 1));
      await tester.tap(find.text('Shell action'));
      await tester.pump();
      expect(shellActions, 1);
      await tester.tap(find.text('Cancel'));
      finish.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Message DayArk…'),
            )
            .controller!
            .text,
        draft,
      );
      expect(await chats.list(), isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'thinking-only completion stays formatted and readable after reopening',
    (tester) async {
      await open(
        tester,
        engine:
            ({
              required message,
              required history,
              required profileId,
              required cancellationToken,
            }) async* {
              yield const AiStreamEvent.activity(
                thinking: '**Checking** the document',
              );
              yield AiStreamEvent.completed(
                AiResponse(
                  selection: AiModelSelection(
                    providerId: profileId!,
                    modelId: 'small',
                  ),
                  message: AiMessage(role: AiRole.assistant, text: ''),
                  thinkingOnly: true,
                  finishReason: 'length',
                ),
              );
            },
      );
      await send(tester, 'A question');
      expect(find.byTooltip('Response error details'), findsNothing);
      expect(
        find.textContaining('Model stopped after thinking'),
        findsOneWidget,
      );
      final reply = (await chats.list()).single.messages.last;
      expect(reply.thinking, '**Checking** the document');
      expect(reply.state, AiChatMessageState.complete);
      await tester.tap(find.byTooltip('New chat').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('A question'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text('Checking the document'), findsOneWidget);
      expect(find.text('**Checking** the document'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'large live answer and thoughts keep the actual Stop control responsive',
    (tester) async {
      final answer = '**Answer** with `code` and useful details.\n\n' * 3000;
      final thoughts = '**Checking** the source.\n\n' * 3000;
      var providerCancelled = false;
      await open(
        tester,
        engine:
            ({
              required message,
              required history,
              required profileId,
              required cancellationToken,
            }) async* {
              yield AiStreamEvent.activity(thinking: thoughts);
              yield AiStreamEvent.delta(answer);
              await cancellationToken.whenCancelled;
              providerCancelled = true;
              cancellationToken.throwIfCancelled();
            },
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Message DayArk…'),
        'A long reply',
      );
      await tester.tap(find.byTooltip('Send message'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byTooltip('Stop response'), findsOneWidget);
      expect(
        tester
            .widgetList<MarkdownBody>(find.byType(MarkdownBody))
            .every((body) => body.data.length <= 4096),
        isTrue,
      );
      await tester.tap(find.byTooltip('Stop response'));
      await tester.pump();
      for (var i = 0; i < 100; i++) {
        // Let background encoding finish, then flush the widget fake clock.
        // Awaiting a DB read here would wait on the transaction's fake-clock continuation.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (find.byTooltip('Send message').evaluate().isNotEmpty) break;
      }
      await tester.pumpAndSettle();
      expect(providerCancelled, isTrue);
      final reply = (await tester.runAsync(() => chats.list()))!
          .single
          .messages
          .last;
      expect(reply.state, AiChatMessageState.stopped);
      expect(reply.message.text, answer);
      expect(reply.thinking, thoughts);
      expect(find.byTooltip('Send message'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('draft clears after persistence while reply is still streaming', (
    tester,
  ) async {
    final finish = Completer<void>();
    await open(
      tester,
      engine:
          ({
            required message,
            required history,
            required profileId,
            required cancellationToken,
          }) async* {
            yield const AiStreamEvent.delta('Working');
            await finish.future;
            yield AiStreamEvent.completed(
              AiResponse(
                selection: AiModelSelection(
                  providerId: profileId!,
                  modelId: 'small',
                ),
                message: AiMessage(role: AiRole.assistant, text: 'Done'),
              ),
            );
          },
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Message DayArk…'),
      'Hello',
    );
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final input = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Message DayArk…'),
    );
    expect(input.controller!.text, isEmpty);
    expect(find.byTooltip('Stop response'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Message DayArk…'),
      'Next question',
    );
    finish.complete();
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    expect(input.controller!.text, 'Next question');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('compact composer fits above the software keyboard', (
    tester,
  ) async {
    await open(tester, mobile: true);
    tester.view.physicalSize = const Size(390, 600);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Message DayArk…',
      ),
      'Line one\nLine two\nLine three\nLine four',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Send message'), findsOneWidget);
    await tester.tap(find.byTooltip('Prompt controls'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disable extra prompt'));
    await tester.pumpAndSettle();
    expect(settings.load().settings.sendAdditionalPrompt, isFalse);
    await tester.tap(find.byTooltip('Prompt controls'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View prompts'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Line one', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'unsaved composer is retained when persistence fails before provider invocation',
    (tester) async {
      await chats.close();
      chats = FailingChatStore(AiChatDatabase(NativeDatabase.memory()));
      await chats.deviceId;
      await open(tester);
      await send(tester, 'Keep this draft');
      final composer = tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Message DayArk…',
        ),
      );
      expect(composer.controller!.text, 'Keep this draft');
      expect(selected, isEmpty);
      expect(
        find.text('Unable to save this chat. Check storage and retry.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'editing a user message can remove an incompatible attachment before retrying',
    (tester) async {
      await chats.save(
        AiConversation(
          id: 'with-attachment',
          title: 'Attachment chat',
          profileId: 'first',
          updatedAt: DateTime.now(),
          messages: [
            AiChatMessage(
              id: 'user',
              createdAt: DateTime.now(),
              message: AiMessage(
                role: AiRole.user,
                text: 'Read this',
                attachments: [
                  AiAttachment(
                    id: 'pdf',
                    kind: AiAttachmentKind.document,
                    mimeType: 'application/pdf',
                    uri: Uri.parse('attachment:pdf'),
                    name: 'report.pdf',
                    bytes: Uint8List.fromList([37, 80, 68, 70, 45]),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      await open(tester);
      await tester.tap(find.text('Attachment chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit message'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove attachment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save and regenerate'));
      await tester.pumpAndSettle();
      expect(
        (await chats.get('with-attachment'))!
            .messages
            .first
            .message
            .attachments,
        isEmpty,
      );
      expect(selected.single, 'first');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('failed provider output stays behind a diagnostic dialog', (
    tester,
  ) async {
    await chats.save(
      AiConversation(
        id: 'failed-chat',
        title: 'Failed chat',
        updatedAt: DateTime.now(),
        messages: [
          AiChatMessage(
            id: 'failed',
            createdAt: DateTime.now(),
            state: AiChatMessageState.failed,
            error: 'AI provider returned an invalid or empty response.',
            diagnostics: 'MODEL THINKING\nSynthetic reasoning\n\nRESPONSE RECEIVED\nNo answer',
            message: AiMessage(
              role: AiRole.assistant,
              text: 'Partial provider output that must stay hidden',
            ),
          ),
        ],
      ),
    );
    await open(tester);
    await tester.tap(find.text('Failed chat'));
    await tester.pumpAndSettle();
    expect(
      find.text('Partial provider output that must stay hidden'),
      findsNothing,
    );
    await tester.tap(find.byTooltip('Response error details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Synthetic reasoning'), findsOneWidget);
    expect(find.textContaining('RESPONSE RECEIVED'), findsOneWidget);
  });

  testWidgets('desktop AI settings stays in the shell content pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? openedRoute;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: DesktopNavigationScope(
            onOpenRoute: (route) => openedRoute = route,
            onDashboard: () {},
            child: AiChatScreen(
              store: chats,
              settings: settings,
              engine: getEngine(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('AI settings'));
    await tester.pump();
    expect(openedRoute, RoutesStr.aiSettings);
    expect(find.byType(AiChatScreen), findsOneWidget);
  });
}
