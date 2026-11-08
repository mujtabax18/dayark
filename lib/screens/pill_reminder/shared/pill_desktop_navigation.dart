import 'package:flutter/material.dart';

/// Navigation bridge used only by the Pill Reminder desktop workspace.
///
/// Mobile/tablet screens keep using their existing Navigator/GoRouter flow.
/// When this scope is present, child pages open inside the Pill Reminder
/// admin-style workspace instead of pushing a full-screen route.
class PillDesktopNavigationScope extends InheritedWidget {
  const PillDesktopNavigationScope({
    super.key,
    required this.onOpenOverview,
    required this.onOpenMedicines,
    required this.onOpenProfiles,
    required this.onOpenSettings,
    required this.onOpenMedicineForm,
    required this.onOpenRefill,
    required this.onCloseDetail,
    required super.child,
  });

  final VoidCallback onOpenOverview;
  final VoidCallback onOpenMedicines;
  final VoidCallback onOpenProfiles;
  final VoidCallback onOpenSettings;
  final ValueChanged<Map<String, dynamic>?> onOpenMedicineForm;
  final void Function(int pillId, String pillName) onOpenRefill;
  final VoidCallback onCloseDetail;

  static PillDesktopNavigationScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PillDesktopNavigationScope>();
  }

  @override
  bool updateShouldNotify(PillDesktopNavigationScope oldWidget) => false;
}
