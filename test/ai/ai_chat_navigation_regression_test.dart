import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/chat/ai_chat_screen.dart';
import 'package:metersystem/ai/chat/ai_chat_store.dart';
import 'package:metersystem/ai/settings/ai_local_models.dart';
import 'package:metersystem/ai/settings/ai_local_models_screen.dart';
import 'package:metersystem/ai/settings/ai_settings_screen.dart';
import 'package:metersystem/ai/settings/ai_settings_store.dart';
import 'package:metersystem/screens/navigation/widgets/desktop_navigation_scope.dart';

import 'ai_model_settings_ui_test.dart' show UiModels;

void main() {
  late AiChatStore chats;
  late AiSettingsStore settings;
  late SharedPreferences prefs;
  final sent = <String>[];
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    settings = AiSettingsStore(preferences: prefs);
    await settings.save(
      AiPreferences(
        profiles: [
          AiProviderProfile(
            id: 'test',
            name: 'Test model',
            kind: AiProviderKind.offline,
            modelId: 'small',
          ),
        ],
        selectedProfileId: 'test',
      ),
    );
    chats = AiChatStore(AiChatDatabase(NativeDatabase.memory()));
    sent.clear();
  });
  tearDown(() => chats.close());

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1400, 900),
    Future<AiLocalModels> Function()? models,
    ValueChanged<String>? route,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            platform: size.width >= 900
                ? TargetPlatform.linux
                : TargetPlatform.android,
          ),
          home: DesktopNavigationScope(
            onOpenRoute: route ?? (_) {},
            onDashboard: () {},
            child: AiChatScreen(
              store: chats,
              settings: settings,
              localModels: models ?? () async => UiModels(),
              engine:
                  ({
                    required message,
                    required history,
                    required profileId,
                    required cancellationToken,
                  }) async* {
                    sent.add(message.text);
                    yield AiStreamEvent.completed(
                      AiResponse(
                        selection: AiModelSelection(
                          providerId: 'test',
                          modelId: 'small',
                        ),
                        message: AiMessage(
                          role: AiRole.assistant,
                          text: List.generate(
                            40,
                            (i) => 'Answer paragraph $i.',
                          ).join('\n\n'),
                        ),
                      ),
                    );
                  },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder getInput() => find.widgetWithText(TextField, 'Message DayArk…');
  Future<void> settingsPage(WidgetTester tester) async {
    await tester.tap(find.byTooltip('AI settings'));
    await tester.pumpAndSettle();
    expect(find.byType(AiSettingsScreen), findsOneWidget);
  }

  Future<void> openModels(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Conversation history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Models'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'settings returns to chat, retains the draft and persists Enter to send',
    (tester) async {
      final routes = <String>[];
      await open(tester, route: routes.add);
      await tester.enterText(getInput(), 'Keep this draft');
      await settingsPage(tester);
      expect(routes, isEmpty);
      await tester.tap(find.text('Enter to send'));
      await tester.pumpAndSettle();
      expect(prefs.getBool('dayark.ai.workspace.enterToSend'), true);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(AiSettingsScreen), findsNothing);
      expect(
        tester.widget<TextField>(getInput()).controller!.text,
        'Keep this draft',
      );
      await tester.enterText(getInput(), 'Send with Enter');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(sent, ['Send with Enter']);
      await tester.enterText(getInput(), 'Line one');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
      expect(
        tester.widget<TextField>(getInput()).controller!.text,
        contains('\n'),
      );
      await tester.enterText(getInput(), 'Send from keyboard action');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(sent.last, 'Send from keyboard action');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Enter adds a newline by default and Ctrl+Enter remains an alternative send',
    (tester) async {
      await open(tester);
      await tester.enterText(getInput(), 'Line one');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      expect(
        tester.widget<TextField>(getInput()).controller!.text,
        contains('\n'),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'message viewport keeps one scroll position when sidebar and breakpoints change',
    (tester) async {
      await open(tester);
      expect(find.text('Back to DayArk'), findsNothing);
      await tester.enterText(getInput(), 'Long reply');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('ai-chat-message-list'));
      final scroll = tester.widget<ListView>(list).controller!;
      await tester.drag(list, const Offset(0, 400));
      await tester.pumpAndSettle();
      final position = scroll.position;
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Toggle sidebar'));
        await tester.pump();
        expect(scroll.positions, hasLength(1));
        expect(scroll.position, same(position));
        expect(tester.takeException(), isNull);
      }
      for (final size in [
        const Size(960, 700),
        const Size(700, 700),
        const Size(1400, 900),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(scroll.positions, hasLength(1));
        expect(tester.takeException(), isNull);
        if (size.width < 900) {
          await tester.tap(find.byTooltip('Conversation history'));
          await tester.pumpAndSettle();
          expect(find.text('Back to DayArk'), findsNothing);
          tester.state<ScaffoldState>(find.byType(Scaffold).last).closeDrawer();
          await tester.pumpAndSettle();
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'mobile Models opens immediately, displays loading and then the actual manager',
    (tester) async {
      final pending = Completer<AiLocalModels>();
      await open(
        tester,
        size: const Size(390, 844),
        models: () => pending.future,
      );
      await openModels(tester);
      expect(find.text('Local model manager'), findsOneWidget);
      expect(
        find.text('Checking hardware and installed models…'),
        findsOneWidget,
      );
      pending.complete(UiModels());
      await tester.pumpAndSettle();
      expect(find.byType(AiLocalModelsScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('How can DayArk help?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'model loading failures show Retry and waiting pages remain navigable',
    (tester) async {
      var attempts = 0;
      await open(
        tester,
        size: const Size(390, 844),
        models: () async {
          if (++attempts == 1) throw StateError('Unavailable storage');
          return UiModels();
        },
      );
      await openModels(tester);
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.byType(AiLocalModelsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
