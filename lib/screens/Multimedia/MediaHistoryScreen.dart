import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_x.dart';
import '../../controller/mediaController.dart';
import '../../models/MediaEditHistory.dart';
import '../../models/MediaFile.dart';

class MediaHistoryScreen extends ConsumerWidget {
  const MediaHistoryScreen({
    super.key,
    required this.media,
  });

  final MediaFile media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neutral = context.themeColors.neutral;
    final id = media.id;
    if (id == null) {
      return const Scaffold(body: Center(child: Text('No history available.')));
    }
    final historyAsync = ref.watch(mediaHistoryProvider(id));

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        title: const Text('Version history'),
        backgroundColor: neutral.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (history) {
          if (history.isEmpty) {
            return const Center(child: Text('No history found.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = history[index];
              final exists = File(entry.outputPath).existsSync();
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    child: Text('v${entry.version}'),
                  ),
                  title: Text(_actionLabel(entry.action)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      '${DateFormat('MMM d, yyyy • HH:mm').format(DateTime.tryParse(entry.createdAt) ?? DateTime.now())}\n'
                      '${exists ? 'File available' : 'File missing — restore backup first'}',
                    ),
                  ),
                  isThreeLine: true,
                  trailing: entry.action == 'moved_to_trash'
                      ? null
                      : OutlinedButton(
                          onPressed: exists
                              ? () => _restore(context, ref, entry)
                              : null,
                          child: const Text('Restore'),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    MediaEditHistory history,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restore version ${history.version}?'),
        content: const Text(
          'A new version will be created from this point. Existing versions and the original will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final restored =
          await ref.read(mediaServiceProvider).restoreVersion(media, history);
      refreshMediaLibrary(ref);
      if (context.mounted) Navigator.pop(context, restored);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $error'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  String _actionLabel(String action) {
    return switch (action) {
      'imported' => 'Original imported',
      'image_edit' => 'Image edited',
      'restore_version' => 'Previous version restored',
      'tts_generated' => 'Speech audio generated',
      'moved_to_trash' => 'Moved to trash',
      _ => action.replaceAll('_', ' '),
    };
  }
}
