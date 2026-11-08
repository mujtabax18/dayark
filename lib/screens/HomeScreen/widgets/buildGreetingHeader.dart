import 'package:flutter/material.dart';

Widget buildGreetingHeader(BuildContext context) {
  final textTheme = Theme.of(context).textTheme;
  final colorScheme = Theme.of(context).colorScheme;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Hello! 👋',
        style: textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Text(
        'Track your meters, expenses, and media effortlessly.',
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}
