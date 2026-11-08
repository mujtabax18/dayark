import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:metersystem/core/theme/theme_x.dart';
import 'package:metersystem/models/moodTrackerModel.dart';
import 'package:metersystem/services/diary_media_service.dart';
import 'package:metersystem/services/diary_reminder_service.dart';
import '../controller/moodNotifier.dart';
import '../widget/DiaryEntrySheet.dart';
import '../../navigation/widgets/desktop_content_frame.dart';
part '../widget/diary_detail_widgets.dart';

class DiaryDetailScreen extends ConsumerStatefulWidget {
  const DiaryDetailScreen({
    super.key,
    required this.entries,
    required this.initialIndex,
  });

  final List<MoodEntry> entries;
  final int initialIndex;

  @override
  ConsumerState<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends ConsumerState<DiaryDetailScreen> {
  late final List<int> _entryIds;
  late final PageController _pageController;
  late int _pageIndex;

  @override
  void initState() {
    super.initState();
    _entryIds = widget.entries
        .where((entry) => entry.id != null)
        .map((entry) => entry.id!)
        .toList(growable: true);

    final requestedId = widget.entries.isEmpty
        ? null
        : widget.entries[widget.initialIndex.clamp(0, widget.entries.length - 1).toInt()].id;
    final resolvedIndex = requestedId == null ? 0 : _entryIds.indexOf(requestedId);
    _pageIndex = resolvedIndex < 0 ? 0 : resolvedIndex;
    _pageController = PageController(initialPage: _pageIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<MoodEntry> _resolveEntries(List<MoodEntry> state) {
    final byId = <int, MoodEntry>{
      for (final entry in state)
        if (entry.id != null) entry.id!: entry,
    };
    return _entryIds
        .map((id) => byId[id])
        .whereType<MoodEntry>()
        .toList(growable: false);
  }

  Future<void> _edit(MoodEntry entry) async {
    await Navigator.push<MoodEntry>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DiaryEntrySheet(existingEntry: entry),
      ),
    );
  }

  Future<void> _delete(MoodEntry entry) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete diary page?'),
        content: const Text(
          'This entry and its private media will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (approved != true || entry.id == null) return;

    await DiaryReminderService.cancel(entry.id!);
    await ref.read(moodProvider.notifier).deleteMood(entry.id!);
    for (final path in [...entry.imagePaths, if (entry.drawingPath != null) entry.drawingPath!]) {
      await DiaryMediaService.deleteIfOwned(path);
    }

    final removedIndex = _entryIds.indexOf(entry.id!);
    _entryIds.remove(entry.id!);
    if (!mounted) return;
    if (_entryIds.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _pageIndex = math.min(removedIndex, _entryIds.length - 1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_pageIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final state = ref.watch(moodProvider);
    final entries = _resolveEntries(state);

    if (entries.isEmpty) {
      return Scaffold(
        backgroundColor: neutral.background,
        appBar: AppBar(backgroundColor: neutral.background),
        body: DesktopContentFrame(
          child: const Center(child: Text('This diary entry is no longer available.')),
        ),
      );
    }

    if (_pageIndex >= entries.length) _pageIndex = entries.length - 1;
    final current = entries[_pageIndex];

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        backgroundColor: neutral.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My diary', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(
              '${_pageIndex + 1} of ${entries.length}',
              style: TextStyle(
                color: neutral.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: current.isFavorite ? 'Remove bookmark' : 'Bookmark page',
            onPressed: current.id == null
                ? null
                : () => ref
                    .read(moodProvider.notifier)
                    .toggleFavorite(current.id!),
            icon: Icon(
              current.isFavorite
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: current.isFavorite ? Color(current.accentColorValue) : null,
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: () => _edit(current),
            icon: const Icon(Icons.edit_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _delete(current);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Delete entry'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: entries.length,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) => setState(() => _pageIndex = index),
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      var page = _pageIndex.toDouble();
                      if (_pageController.hasClients &&
                          _pageController.position.haveDimensions) {
                        page = _pageController.page ?? page;
                      }
                      final delta = (index - page).clamp(-1.0, 1.0).toDouble();
                      final scale = 1 - (delta.abs() * .055);
                      final angle = delta * -.055;
                      return Transform(
                        alignment: delta > 0
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, .0012)
                          ..rotateY(angle)
                          ..scale(scale),
                        child: Opacity(
                          opacity: 1 - delta.abs() * .14,
                          child: child,
                        ),
                      );
                    },
                    child: _DiaryPaperPage(
                      entry: entries[index],
                      onMediaTap: (paths, selectedIndex) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _DiaryMediaViewer(
                              paths: paths,
                              initialIndex: selectedIndex,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            if (entries.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.swipe_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Swipe to turn diary pages',
                      style: TextStyle(
                        color: neutral.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

