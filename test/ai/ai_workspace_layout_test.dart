import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metersystem/ai/chat/ai_chat_screen.dart';
import 'package:metersystem/ai/chat/ai_chat_store.dart';
import 'package:metersystem/ai/settings/ai_settings_store.dart';
import 'package:metersystem/ai/settings/ai_preferences.dart';

void main() {
  for (final size in [
    const Size(320, 600),
    const Size(600, 800),
    const Size(960, 640),
    const Size(1400, 900),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'workspace fits ${size.width} × ${size.height} in ${brightness.name}',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final settings = AiSettingsStore(preferences: prefs);
          await settings.save(
            AiPreferences(
              profiles: [
                AiProviderProfile(
                  id: 'local',
                  name: 'Qwen3.5 4B',
                  kind: AiProviderKind.offline,
                  modelId: 'Qwen3.5 4B',
                ),
              ],
              selectedProfileId: 'local',
            ),
          );
          final store = AiChatStore(AiChatDatabase(NativeDatabase.memory()));
          addTearDown(store.close);
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final boundary = GlobalKey();
          if (const bool.fromEnvironment('DAYARK_AI_SCREENSHOTS')) {
            await tester.runAsync(() async {
              final bytes = await File(
                const String.fromEnvironment('DAYARK_AI_PREVIEW_FONT'),
              ).readAsBytes();
              final loader = FontLoader('WorkspacePreview');
              loader.addFont(Future.value(ByteData.sublistView(bytes)));
              await loader.load();
              final iconFont = File(
                '${File(const String.fromEnvironment('DAYARK_AI_PREVIEW_FONT')).parent.path}/MaterialIcons-Regular.otf',
              );
              final icons = FontLoader('MaterialIcons');
              icons.addFont(
                Future.value(
                  ByteData.sublistView(await iconFont.readAsBytes()),
                ),
              );
              await icons.load();
            });
          }
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: ThemeData(
                  useMaterial3: true,
                  fontFamily:
                      const bool.fromEnvironment('DAYARK_AI_SCREENSHOTS')
                      ? 'WorkspacePreview'
                      : null,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xff21866b),
                    brightness: brightness,
                  ),
                ),
                home: RepaintBoundary(
                  key: boundary,
                  child: AiChatScreen(
                    store: store,
                    settings: settings,
                    engine: ({
                      required message,
                      required history,
                      required profileId,
                      required cancellationToken,
                    }) async* {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('How can DayArk help?'), findsOneWidget);
          if (size.width >= 1180) {
            expect(
              find.byKey(const ValueKey('ai-runtime-inspector')),
              findsOneWidget,
            );
            await tester.tap(find.byTooltip('Toggle inspector'));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('ai-runtime-inspector')),
              findsNothing,
            );
            expect(prefs.getBool('dayark.ai.workspace.inspector'), false);
            await tester.tap(find.byTooltip('Toggle inspector'));
            await tester.pumpAndSettle();
          }
          if (size.width >= 900) {
            await tester.tap(find.byTooltip('Toggle sidebar'));
            await tester.pumpAndSettle();
            expect(prefs.getBool('dayark.ai.workspace.collapsed'), true);
            await tester.tap(find.byTooltip('Toggle sidebar'));
            await tester.pumpAndSettle();
          }
          if (const bool.fromEnvironment('DAYARK_AI_SCREENSHOTS')) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '/tmp/dayark-ai-${size.width.toInt()}-${brightness.name}.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
