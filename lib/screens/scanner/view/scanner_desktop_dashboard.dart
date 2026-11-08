import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/backupService.dart';
import '../../../services/database_service.dart';
import '../../../services/restoreService.dart';
import '../../Settings/components/backup_password_dialog.dart';
import '../../navigation/widgets/desktop_navigation_scope.dart';
import '../controllers/provideers/scanGroupRepoProvider.dart';
import '../data/models/ScanGroupPreview.dart';
import 'ScanGroupViewScreen.dart';
import 'scanner_gallery_screen.dart';

part 'parts/scanner_desktop_dashboard_scanner_desktop_section.dart';
part 'parts/scanner_desktop_dashboard_sidebar_item.dart';

/// Desktop-only document scanner workspace.
///
/// The scanner has its own second-level sidebar and nested navigator. Every
/// scanner screen therefore remains inside the desktop admin shell's right
/// content area. Camera capture stays a mobile-only capability.
class ScannerDesktopDashboard extends ConsumerStatefulWidget {
  const ScannerDesktopDashboard({super.key});

  @override
  ConsumerState<ScannerDesktopDashboard> createState() =>
      _ScannerDesktopDashboardState();
}

