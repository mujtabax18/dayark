import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/settings/ai_flutter_settings.dart';
import 'package:metersystem/screens/navigation/widgets/desktop_navigation_scope.dart';
import 'package:metersystem/utlis/app_router.dart';

void main() {
  late AiSettingsStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    store = AiSettingsStore(preferences: await SharedPreferences.getInstance());
    await store.save(
      AiPreferences(
        profiles: [
          AiProviderProfile(
            id: 'api',
            name: 'API',
            kind: AiProviderKind.openai,
            modelId: 'test-model',
          ),
        ],
        selectedProfileId: 'api',
      ),
    );
  });
  testWidgets('settings back pops an ordinary pushed screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => AiSettingsScreen(store: store),
                ),
              ),
              child: const Text('Open AI settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open AI settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Open AI settings'), findsOneWidget);
    expect(find.byType(AiSettingsScreen), findsNothing);
  });
  testWidgets('desktop settings back stays in shell and opens main Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopNavigationScope(
          onOpenRoute: (route) => opened = route,
          onDashboard: () {},
          child: AiSettingsScreen(store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    expect(opened, RoutesStr.settings);
  });
  testWidgets('direct AI settings route has a main Settings fallback', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: RoutesStr.aiSettings,
      routes: [
        GoRoute(
          path: RoutesStr.settings,
          builder: (_, _) => const Scaffold(body: Text('Main Settings')),
        ),
        GoRoute(
          path: RoutesStr.aiSettings,
          builder: (_, _) => AiSettingsScreen(store: store),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Main Settings'), findsOneWidget);
  });
}
