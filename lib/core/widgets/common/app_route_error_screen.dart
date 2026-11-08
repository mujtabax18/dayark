import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_empty_state.dart';

class AppRouteErrorScreen extends StatelessWidget {
  const AppRouteErrorScreen({
    super.key,
    this.title = 'Page unavailable',
    this.message = 'The requested page could not be opened safely.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: title,
        message: message,
        actionLabel: 'Go home',
        onAction: () => context.go('/'),
      ),
    );
  }
}
