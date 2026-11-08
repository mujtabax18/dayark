import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:metersystem/core/theme/theme_x.dart';
import 'package:metersystem/models/moodTrackerModel.dart';
import '../view/DiaryDetailScreen.dart';

class DiaryListItem extends StatelessWidget {
  const DiaryListItem({
    super.key,
    required this.entry,
    required this.entries,
    required this.index,
  });

  final MoodEntry entry;
  final List<MoodEntry> entries;
  final int index;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final accent = Color(entry.accentColorValue);
    final thumbnailPath = entry.imagePaths.isNotEmpty
        ? entry.imagePaths.first
        : entry.drawingPath;
    final hasThumbnail = thumbnailPath != null && File(thumbnailPath).existsSync();

    return Hero(
      tag: 'diary-card-${entry.id ?? entry.dateTime}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 420),
                reverseTransitionDuration: const Duration(milliseconds: 320),
                pageBuilder: (_, animation, secondaryAnimation) {
                  return DiaryDetailScreen(
                    entries: entries,
                    initialIndex: index,
                  );
                },
                transitionsBuilder: (_, animation, secondaryAnimation, child) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  );
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(.08, 0),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: neutral.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: neutral.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .045),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 6, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Text(
                                  entry.moodEmoji,
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.effectiveTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: neutral.textPrimary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('EEE, d MMM yyyy • h:mm a')
                                          .format(entry.entryDateTime),
                                      style: TextStyle(
                                        color: neutral.textSecondary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (entry.isFavorite)
                                Icon(
                                  Icons.bookmark_rounded,
                                  color: accent,
                                  size: 22,
                                ),
                            ],
                          ),
                          if ((entry.notes ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              entry.notes!.trim(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: neutral.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              if (entry.trigger != null)
                                _MiniChip(
                                  icon: Icons.auto_awesome_rounded,
                                  label: entry.trigger!,
                                  color: accent,
                                ),
                              ...entry.tags.take(3).map(
                                    (tag) => _MiniChip(
                                      icon: Icons.tag_rounded,
                                      label: tag,
                                      color: accent,
                                    ),
                                  ),
                              if (entry.reminderEnabled &&
                                  entry.reminderDateTime != null)
                                _MiniChip(
                                  icon: Icons.notifications_active_rounded,
                                  label: DateFormat('d MMM, h:mm a')
                                      .format(entry.reminderDateTime!),
                                  color: accent,
                                ),
                              _MiniChip(
                                icon: Icons.text_fields_rounded,
                                label: '${entry.wordCount} words',
                                color: accent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (hasThumbnail)
                    SizedBox(
                      width: 104,
                      child: Image.file(
                        File(thumbnailPath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
