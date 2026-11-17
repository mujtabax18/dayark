import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/controller/UserSettingsController.dart';
import 'package:metersystem/models/HomeFeatureModel.dart';
import 'package:metersystem/models/HomeLayoutSettings.dart';
import 'package:metersystem/services/database_service.dart';
import 'package:metersystem/services/localDatabaseServices/UserSettingsRepository.dart';
import 'package:metersystem/utlis/enums.dart';
import 'package:metersystem/utlis/app_router.dart';
import 'package:metersystem/screens/HomeScreen/widgets/home_feature_card.dart';
import 'package:metersystem/screens/navigation/widgets/desktop_navigation_scope.dart';

class MemorySettings extends UserSettingsRepository {
  MemorySettings() : super(DatabaseService());
  final values = <AppSettingKey, String>{};
  @override
  Future<String?> getValue(AppSettingKey key, {int userId = 0}) async =>
      values[key];
  @override
  Future<void> setValue(
    AppSettingKey key,
    String value, {
    int userId = 0,
  }) async {
    values[key] = value;
  }
}

void main() {
  test('AI Chat is a registered feature with a default Home shortcut', () {
    final ai = HomeFeatureModel.defaultFeaturesById[15]!;
    expect(ai.title, 'AI Chat');
    expect(ai.route, RoutesStr.aiChat);
    expect(homeIconList[ai.iconCode], Icons.auto_awesome_outlined);
    expect(HomeLayoutSettings.defaultVisibleQuickAccessIds, contains(15));
    expect(
      HomeFeatureModel.fromMap({'id': 15, 'position': 2}).route,
      RoutesStr.aiChat,
    );
  });
  test(
    'existing shortcuts gain AI Chat once and respect later hiding',
    () async {
      final repo = MemorySettings();
      repo.values.addAll({
        AppSettingKey.homeVisibleQuickAccess: '1,3',
        AppSettingKey.familyTreeHomeShortcutMigrated: '1',
      });
      final controller = UserSettingsController(repo);
      expect(await controller.getHomeVisibleQuickAccess(), {1, 3, 15});
      expect(repo.values[AppSettingKey.aiChatHomeShortcutMigrated], '1');
      await controller.setHomeVisibleQuickAccess({1, 3});
      expect(await controller.getHomeVisibleQuickAccess(), {1, 3});
    },
  );
  test('fresh installs retain a later choice to hide AI Chat', () async {
    final controller = UserSettingsController(MemorySettings());
    expect(await controller.getHomeVisibleQuickAccess(), contains(15));
    await controller.setHomeVisibleQuickAccess({1});
    expect(await controller.getHomeVisibleQuickAccess(), {1});
  });
  testWidgets('AI Chat feature card opens the existing chat workspace', (
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
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 180,
                child: HomeFeatureCard(
                  feature: HomeFeatureModel.defaultFeaturesById[15]!,
                  index: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI Chat'));
    await tester.pumpAndSettle();
    expect(opened, RoutesStr.aiChat);
  });
}
