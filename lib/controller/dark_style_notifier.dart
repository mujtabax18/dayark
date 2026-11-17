import 'package:flutter_riverpod/legacy.dart';

import '../core/theme/app_dark_style.dart';
import 'UserSettingsController.dart';

class DarkStyleNotifier extends StateNotifier<AppDarkStyle> {
  DarkStyleNotifier(this.settingsController, AppDarkStyle initialStyle)
    : super(initialStyle);

  final UserSettingsController settingsController;

  Future<void> setStyle(AppDarkStyle style) async {
    if (state == style) return;
    await settingsController.setDarkStyle(style);
    if (mounted) state = style;
  }
}

final darkStyleProvider =
    StateNotifierProvider<DarkStyleNotifier, AppDarkStyle>((ref) {
      throw UnimplementedError(
        'darkStyleProvider must be overridden in main()',
      );
    });
