import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Exposes the desktop admin shell's right-pane navigation to descendants.
///
/// Phone/tablet callers continue to use normal GoRouter navigation; on desktop
/// this keeps feature modules inside the workspace to the right of the sidebar.
class DesktopNavigationScope extends InheritedWidget {
  const DesktopNavigationScope({
    super.key,
    required this.onOpenRoute,
    required this.onDashboard,
    required super.child,
  });

  final ValueChanged<String> onOpenRoute;
  final VoidCallback onDashboard;

  static DesktopNavigationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DesktopNavigationScope>();
  }

  @override
  bool updateShouldNotify(DesktopNavigationScope oldWidget) => false;
}

Future<T?> openResponsiveModule<T>(
  BuildContext context,
  String route, {
  Object? extra,
}) {
  final desktopScope = DesktopNavigationScope.maybeOf(context);
  if (MediaQuery.sizeOf(context).width >= 1100 &&
      desktopScope != null &&
      extra == null) {
    desktopScope.onOpenRoute(route);
    return Future<T?>.value();
  }

  return context.push<T>(route, extra: extra);
}
