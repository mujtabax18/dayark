import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Shared responsive rules for the app.
///
/// Keep layout decisions here instead of scattering raw MediaQuery breakpoints
/// through individual screens. This also makes web/desktop resizing react in
/// real time while preserving the existing compact phone layout.
abstract final class AppBreakpoints {
  static const double tablet = 600;
  static const double navigationRail = 720;
  static const double desktop = 1024;
  static const double wideDesktop = 1280;
}

enum AppWindowClass { compact, medium, expanded }

extension ResponsiveBuildContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  AppWindowClass get windowClass {
    if (screenWidth >= AppBreakpoints.desktop) {
      return AppWindowClass.expanded;
    }
    if (screenWidth >= AppBreakpoints.tablet) {
      return AppWindowClass.medium;
    }
    return AppWindowClass.compact;
  }

  bool get isCompact => windowClass == AppWindowClass.compact;
  bool get isTablet => windowClass == AppWindowClass.medium;
  bool get isDesktop => windowClass == AppWindowClass.expanded;
  bool get usesNavigationRail => screenWidth >= AppBreakpoints.navigationRail;
  bool get usesExtendedNavigationRail =>
      screenWidth >= AppBreakpoints.wideDesktop;

  double get responsiveHorizontalPadding {
    if (screenWidth >= AppBreakpoints.wideDesktop) return AppSpacing.xxl;
    if (screenWidth >= AppBreakpoints.desktop) return AppSpacing.xl;
    if (screenWidth >= AppBreakpoints.tablet) return AppSpacing.lg;
    return AppSpacing.lg;
  }

  /// Bottom breathing room for pages in the main shell. Phones need extra
  /// space for the docked FAB + BottomAppBar; rail layouts do not.
  double get mainShellBottomPadding => usesNavigationRail ? 32 : 112;
}

/// Keeps long-form/dashboard content readable on large monitors while still
/// taking the full available width on phones and smaller tablets.
class ResponsivePageFrame extends StatelessWidget {
  const ResponsivePageFrame({
    super.key,
    required this.child,
    this.maxWidth = AppConstraints.maxDesktopContentWidth,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: child,
        ),
      ),
    );
  }
}

/// Generic centered content constraint for forms/cards that should not become
/// excessively wide on desktop.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = AppConstraints.maxDesktopContentWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}
