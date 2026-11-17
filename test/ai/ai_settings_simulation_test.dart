import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/settings/ai_flutter_settings.dart';

// Explicit local integration run only; no vendor traffic or paid generation.
// flutter test --no-pub --dart-define=DAYARK_AI_SIMULATION=true test/ai/ai_settings_simulation_test.dart
void main() {
  if (!const bool.fromEnvironment('DAYARK_AI_SIMULATION')) return;
  testWidgets(
    'settings discovers selectable models and tests saved provider profiles over real HTTP',
    (tester) async {
      final previousHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = previousHttpOverrides);
      tester.view.physicalSize = const Size(1100, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final store = AiSettingsStore(
        preferences: await SharedPreferences.getInstance(),
      );
      for (final spec in [
        (AiProviderKind.openai, 'openai/v1/'),
        (AiProviderKind.gemini, 'gemini/v1beta/'),
        (AiProviderKind.anthropic, 'anthropic/v1/'),
        (AiProviderKind.ollama, 'ollama/api/'),
        (AiProviderKind.compatible, 'compatible/v1/'),
      ]) {
        final id = spec.$1.name;
        await store.save(
          AiPreferences(
            profiles: [
              AiProviderProfile(
                id: id,
                name: id,
                kind: spec.$1,
                modelId: 'initial-model',
                baseUrl: 'http://127.0.0.1:4017/${spec.$2}',
              ),
            ],
            selectedProfileId: id,
            allowOnlineProcessing: true,
          ),
        );
        await store.setCredential(id, 'synthetic-test-key');
        await tester.pumpWidget(
          MaterialApp(
            home: AiSettingsScreen(key: ValueKey(id), store: store),
          ),
        );
        await tester.pumpAndSettle();

        // Real socket operations run outside the widget fake clock.
        await tester.runAsync(() async {
          await tester.tap(find.text('Discover models'));
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
        await tester.pumpAndSettle();
        expect(
          find.textContaining('models added to the model picker'),
          findsOneWidget,
          reason:
              '$id: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).where((s) => s != null).join(' | ')}',
        );
        await tester.tap(find.widgetWithText(ListTile, 'Model'));
        await tester.pumpAndSettle();
        final modelId = spec.$1 == AiProviderKind.ollama
            ? 'test-chat:latest'
            : 'test-chat';
        await tester.tap(find.text(modelId).last);
        await tester.pumpAndSettle();

        await tester.runAsync(() async {
          await tester.tap(find.text('Test connection'));
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
        await tester.pumpAndSettle();
        expect(find.text('Connection successful.'), findsOneWidget, reason: id);
        await tester.ensureVisible(find.text('Save settings'));
        await tester.tap(find.text('Save settings'));
        await tester.pumpAndSettle();
        expect(store.load().selectedProfile!.modelId, modelId, reason: id);
      }
    },
  );
}
