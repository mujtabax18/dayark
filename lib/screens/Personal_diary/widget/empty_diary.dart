import 'package:flutter/material.dart';

import 'package:metersystem/core/theme/theme_x.dart';

class EmptyDiary extends StatelessWidget {
  const EmptyDiary({
    super.key,
    this.onCreate,
    this.filtered = false,
  });

  final VoidCallback? onCreate;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112,
              height: 132,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  topLeft: Radius.circular(5),
                  bottomLeft: Radius.circular(5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .12),
                    blurRadius: 18,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 11,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 3,
                      color: Colors.white.withValues(alpha: .2),
                    ),
                  ),
                  const Center(
                    child: Icon(
                      Icons.auto_stories_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              filtered ? 'No matching diary pages' : 'Your story starts here',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: neutral.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 9),
            Text(
              filtered
                  ? 'Try another date, tag, or search phrase.'
                  : 'Capture today with words, photos, reminders, tags, and drawings.',
              style: TextStyle(
                color: neutral.textSecondary,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            if (onCreate != null && !filtered) ...[
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Write first page'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
