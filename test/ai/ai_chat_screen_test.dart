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
  Future<void> open(WidgetTester tester, {bool mobile = false}) async {
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
            engine: getEngine(),
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
    'chat renders Markdown/code safely and switches models without losing conversation',
    (tester) async {
      await open(tester);
      await send(tester, 'Question one');
      expect(find.byType(MarkdownBody), findsNWidgets(2));
      expect(find.text('[Image: blocked]'), findsOneWidget);
      final profile = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'AI profile',
      );
      await tester.tap(profile);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Online · gpt-6.1-sol').last);
      await tester.pumpAndSettle();
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
      await tester.tap(find.byTooltip('Copy message').last);
      await tester.pump();
      expect(clipboard, contains('اردو'));
      await tester.ensureVisible(find.text('Edit'));
      await tester.tap(find.text('Edit'));
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
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share with paired devices'));
      await tester.pumpAndSettle();
      expect((await chats.list()).single.shareWithDevices, isTrue);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(await chats.syncEnabled, isTrue);
      await tester.tap(find.byTooltip('Sync shared chats now'));
      await tester.pumpAndSettle();
      expect(find.text('Test sync complete.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
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
      await tester.tap(find.text('Edit'));
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
}
