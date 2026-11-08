import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/design/responsive_layout.dart';
import '../../../core/theme/theme_x.dart';
import '../../../core/widgets/common/app_dialogs.dart';
import '../../../controller/currency_notifier.dart';
import '../../../controller/locale_notifier.dart';
import '../../../controller/theme_notifier.dart';
import '../../../controller/theme_preset_notifier.dart';
import '../../../core/theme/app_theme_preset.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/HomeLayoutSettings.dart';
import '../../../models/currency_setting.dart';
import '../../../services/database_service.dart';
import '../../../services/app_update/app_update_coordinator.dart';
import '../../../services/app_update/app_update_preferences.dart';
import '../../../services/app_update/app_update_service.dart';
import '../../../services/db/demo_data_seeder.dart';
import '../../HomeScreen/controller/dashboard_provider.dart';
import '../../HomeScreen/controller/home_layout_provider.dart';
import '../../navigation/widgets/desktop_navigation_scope.dart';
import '../../../utlis/app_router.dart';
import '../components/SettingsDivider.dart';
import '../components/SettingsGroup.dart';
import '../components/SettingsTile.dart';
import '../components/summary_widget.dart';
import '../controller/backup_restore_Provider.dart';

part 'parts/backup_screen_setting_screen.dart';
part 'parts/backup_screen_delete_all_database_dialog.dart';

