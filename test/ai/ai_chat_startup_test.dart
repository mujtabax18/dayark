import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metersystem/ai/chat/ai_chat_screen.dart';
import 'package:metersystem/ai/chat/ai_chat_store.dart';
import 'package:metersystem/ai/memory/memory_store.dart';
import 'package:metersystem/ai/settings/ai_local_models.dart';
import 'package:metersystem/ai/settings/ai_preferences.dart';
import 'package:metersystem/ai/settings/ai_settings_store.dart';

class SlowStartupStore extends AiChatStore {
  SlowStartupStore(super.database);
  Completer<bool>? pending;
  @override
  Future<bool> get syncEnabled => pending?.future ?? super.syncEnabled;
}

void main() {
  late SlowStartupStore store;
  late AiSettingsStore settings;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = AiSettingsStore(
      preferences: await SharedPreferences.getInstance(),
    );
    await settings.save(
      AiPreferences(
        profiles: [
          AiProviderProfile(
            id: 'local',
            name: 'Local model',
            kind: AiProviderKind.offline,
            modelId: 'small',
          ),
        ],
        selectedProfileId: 'local',
      ),
    );
    store = SlowStartupStore(AiChatDatabase(NativeDatabase.memory()));
  });
  tearDown(() => store.close());

  Future<void> open(
    WidgetTester tester,
    AiChatScreen screen, {
    bool loading = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => screen),
                  ),
                  child: const Text('Open AI chat'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open AI chat'));
    if (loading) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    } else {
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'real chat path opens without model verification or memory startup and sidebar back exits',
    (tester) async {
      var modelLoads = 0, memoryLoads = 0;
      final models = Completer<AiLocalModels>(),
          memory = Completer<MemoryManager>();
      await open(
        tester,
        AiChatScreen(
          store: store,
          settings: settings,
          localModels: () {
            modelLoads++;
            return models.future;
          },
          memory: () {
            memoryLoads++;
            return memory.future;
          },
        ),
      );
      expect(find.text('How can DayArk help?'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(modelLoads, 0);
      expect(memoryLoads, 0);
      await tester.tap(find.byTooltip('Conversation history'));
      await tester.pumpAndSettle();
      expect(find.text('Saved responses'), findsOneWidget);
      await tester.tap(find.text('Back to DayArk'));
      await tester.pumpAndSettle();
      expect(find.text('Open AI chat'), findsOneWidget);
      expect(find.byType(AiChatScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile sidebar can exit while required chat storage is still loading',
    (tester) async {
      store.pending = Completer<bool>();
      await open(
        tester,
        AiChatScreen(store: store, settings: settings),
        loading: true,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      await tester.tap(find.byTooltip('Conversation history'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Back to DayArk'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(find.text('Open AI chat'), findsOneWidget);
      expect(find.byType(AiChatScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'startup storage timeout gives Retry and a late first attempt cannot replace it',
    (tester) async {
      store.pending = Completer<bool>();
      await open(
        tester,
        AiChatScreen(store: store, settings: settings),
        loading: true,
      );
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      final old = store.pending!;
      store.pending = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('How can DayArk help?'), findsOneWidget);
      old.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('How can DayArk help?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'model preparation starts only on send and remains stoppable if detection hangs',
    (tester) async {
      var modelLoads = 0, memoryLoads = 0;
      final models = Completer<AiLocalModels>();
      await open(
        tester,
        AiChatScreen(
          store: store,
          settings: settings,
          localModels: () {
            modelLoads++;
            return models.future;
          },
          memory: () {
            memoryLoads++;
            return Completer<MemoryManager>().future;
          },
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Message DayArk…'),
        'Hello',
      );
      await tester.tap(find.byTooltip('Send message'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(modelLoads, 1);
      expect(memoryLoads, 0);
      expect(find.byTooltip('Stop response'), findsOneWidget);
      await tester.tap(find.byTooltip('Stop response'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Send message'), findsOneWidget);
      expect(find.textContaining('Response stopped.'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a directly opened GoRouter chat returns home from its mobile sidebar',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/ai-chat',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/ai-chat',
            builder: (_, _) => AiChatScreen(store: store, settings: settings),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsNothing);
      await tester.tap(find.byTooltip('Conversation history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to DayArk'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
