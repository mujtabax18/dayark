import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:metersystem/core/theme/theme_x.dart';
import 'package:metersystem/models/moodTrackerModel.dart';
import 'package:metersystem/services/diary_media_service.dart';
import 'package:metersystem/services/diary_reminder_service.dart';
import '../controller/moodNotifier.dart';
import '../view/drawing_board_screen.dart';
part 'diary_entry_sheet_widgets.dart';

class DiaryEntrySheet extends ConsumerStatefulWidget {
  const DiaryEntrySheet({
    super.key,
    this.existingEntry,
    this.initialDate,
    this.embedded = false,
    this.onClose,
    this.onSaved,
  });

  final MoodEntry? existingEntry;
  final DateTime? initialDate;
  final bool embedded;
  final VoidCallback? onClose;
  final ValueChanged<MoodEntry>? onSaved;

  @override
  ConsumerState<DiaryEntrySheet> createState() => _DiaryEntrySheetState();
}

class _DiaryEntrySheetState extends ConsumerState<DiaryEntrySheet>
    with WidgetsBindingObserver {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _gratitudeController = TextEditingController();
  final _tagController = TextEditingController();
  final _imagePicker = ImagePicker();

  late DateTime _selectedDate;
  late String _selectedEmoji;
  String? _selectedTrigger;
  late List<String> _tags;
  late List<String> _imagePaths;
  String? _drawingPath;
  DateTime? _reminderAt;
  bool _reminderEnabled = false;
  bool _saving = false;
  late int _accentColorValue;

  final Set<String> _removedMedia = {};
  final Set<String> _newMedia = {};

  MoodEntry? _persistedEntry;
  Timer? _autoSaveTimer;
  Timer? _checkpointTimer;
  Future<void> _saveChain = Future<void>.value();
  int _changeRevision = 0;
  int _lastSavedRevision = 0;
  String? _lastSavedFingerprint;
  String? _lastSyncedReminderKey;
  String? _autoSaveError;

  static const _autoSaveDelay = Duration(milliseconds: 800);
  static const _checkpointInterval = Duration(seconds: 5);

  static const _triggers = <String>[
    'Work',
    'Family',
    'Health',
    'Relationships',
    'Personal growth',
    'Travel',
    'Celebration',
    'Other',
  ];

  static const _accentColors = <int>[
    0xFF6C63FF,
    0xFF0E7490,
    0xFF15803D,
    0xFFD97706,
    0xFFDC2626,
    0xFFBE185D,
    0xFF7C3AED,
    0xFF475569,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final entry = widget.existingEntry;
    _persistedEntry = entry;
    _titleController.text = entry?.title ?? '';
    _notesController.text = entry?.notes ?? '';
    _gratitudeController.text = entry?.gratitude ?? '';
    final now = DateTime.now();
    final initialDate = widget.initialDate;
    _selectedDate = entry?.entryDateTime ??
        (initialDate == null
            ? now
            : DateTime(
                initialDate.year,
                initialDate.month,
                initialDate.day,
                now.hour,
                now.minute,
              ));
    final storedEmoji = entry?.moodEmoji;
    _selectedEmoji = storedEmoji == null || storedEmoji.trim().isEmpty
        ? '😊'
        : storedEmoji;
    _selectedTrigger = entry?.trigger;
    _tags = [...?entry?.tags];
    _imagePaths = [...?entry?.imagePaths];
    _drawingPath = entry?.drawingPath;
    _reminderAt = entry?.reminderDateTime;
    _reminderEnabled = entry?.reminderEnabled ?? false;
    _accentColorValue = entry?.accentColorValue ?? _accentColors.first;

    if (entry != null) {
      _lastSavedFingerprint = _entryFingerprint(entry);
    }
    _lastSyncedReminderKey = _reminderKey();

    _titleController.addListener(_onEditorTextChanged);
    _notesController.addListener(_onEditorTextChanged);
    _gratitudeController.addListener(_onEditorTextChanged);

    _checkpointTimer = Timer.periodic(_checkpointInterval, (_) {
      if (_isDirty) {
        unawaited(_runAutoSave());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _autoSaveTimer?.cancel();
      if (_isDirty) {
        unawaited(_runAutoSave());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    _checkpointTimer?.cancel();
    _titleController.removeListener(_onEditorTextChanged);
    _notesController.removeListener(_onEditorTextChanged);
    _gratitudeController.removeListener(_onEditorTextChanged);

    // Only media that never reached a successful autosave/manual save is
    // cleaned up here. Successfully persisted media is removed from _newMedia.
    for (final path in _newMedia) {
      unawaited(DiaryMediaService.deleteIfOwned(path));
    }

    _titleController.dispose();
    _notesController.dispose();
    _gratitudeController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  bool get _isDirty => _changeRevision != _lastSavedRevision;

  void _onEditorTextChanged() => _markDirty();

  void _markDirty({bool saveImmediately = false}) {
    final wasDirty = _isDirty;
    _changeRevision++;
    _autoSaveError = null;

    _autoSaveTimer?.cancel();
    if (saveImmediately) {
      unawaited(_runAutoSave());
    } else {
      _autoSaveTimer = Timer(_autoSaveDelay, () {
        unawaited(_runAutoSave());
      });
    }

    if (!wasDirty && mounted) {
      setState(() {});
    }
  }

  MoodEntry _buildEntry() {
    final existing = _persistedEntry ?? widget.existingEntry;
    final rawTitle = _titleController.text.trim();
    final rawNotes = _notesController.text.trim();
    final rawGratitude = _gratitudeController.text.trim();
    final emoji = _selectedEmoji.trim();

    return MoodEntry(
      id: existing?.id,
      dateTime: _selectedDate.toIso8601String(),
      moodEmoji: emoji.isEmpty ? '😊' : emoji,
      trigger: _selectedTrigger,
      notes: rawNotes.isEmpty ? null : rawNotes,
      title: rawTitle.isEmpty ? 'Untitled diary page' : rawTitle,
      gratitude: rawGratitude.isEmpty ? null : rawGratitude,
      tags: List<String>.unmodifiable(_tags),
      imagePaths: List<String>.unmodifiable(_imagePaths),
      drawingPath: _drawingPath,
      reminderAt: _reminderAt?.toIso8601String(),
      reminderEnabled: _reminderEnabled,
      isFavorite: existing?.isFavorite ?? false,
      accentColorValue: _accentColorValue,
      createdAt: existing?.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  String _entryFingerprint(MoodEntry entry) {
    final data = Map<String, dynamic>.from(entry.toMap())
      ..remove('id')
      ..remove('createdAt')
      ..remove('updatedAt');
    return jsonEncode(data);
  }

  String _reminderKey() =>
      '${_reminderEnabled ? 1 : 0}|${_reminderAt?.toIso8601String() ?? ''}';

  Future<MoodEntry?> _queuePersist({required bool isManual}) {
    final completer = Completer<MoodEntry?>();
    _saveChain = _saveChain.then((_) async {
      try {
        final saved = await _persistNow(isManual: isManual);
        completer.complete(saved);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<MoodEntry?> _persistNow({required bool isManual}) async {
    final shouldCreate = _persistedEntry == null;
    if (!_isDirty && !shouldCreate) {
      return _persistedEntry;
    }

    final revisionAtStart = _changeRevision;
    final entry = _buildEntry();
    final fingerprint = _entryFingerprint(entry);
    final newMediaAtStart = Set<String>.from(_newMedia);
    final removedMediaAtStart = Set<String>.from(_removedMedia);

    if (!shouldCreate && fingerprint == _lastSavedFingerprint) {
      _lastSavedRevision = revisionAtStart;
      if (mounted) setState(() {});
      return _persistedEntry;
    }

    if (mounted && !_saving) {
      setState(() => _saving = true);
    }

    try {
      final saved =
          await ref.read(moodProvider.notifier).addOrUpdateMood(entry);
      _persistedEntry = saved;
      _lastSavedFingerprint = fingerprint;
      if (revisionAtStart > _lastSavedRevision) {
        _lastSavedRevision = revisionAtStart;
      }
      _autoSaveError = null;

      // These files are now referenced by a successfully persisted diary row,
      // so dispose() must never treat them as abandoned temporary media.
      _newMedia.removeAll(newMediaAtStart);

      final reminderKey = _reminderKey();
      if (reminderKey != _lastSyncedReminderKey) {
        try {
          final reminderDate = saved.reminderDateTime;
          if (saved.reminderEnabled &&
              reminderDate != null &&
              reminderDate.isAfter(DateTime.now())) {
            await DiaryReminderService.scheduleFor(saved);
            _lastSyncedReminderKey = reminderKey;
          } else if (!saved.reminderEnabled && saved.id != null) {
            await DiaryReminderService.cancel(saved.id!);
            _lastSyncedReminderKey = reminderKey;
          }
        } catch (error) {
          if (isManual && mounted) {
            _showMessage(
              'The diary page was saved, but its reminder could not be scheduled: $error',
            );
          }
        }
      }

      for (final path in removedMediaAtStart) {
        try {
          await DiaryMediaService.deleteIfOwned(path);
          _removedMedia.remove(path);
        } catch (_) {
          // The diary row is already safely saved. Keep the path queued so a
          // later save can retry cleanup without reporting a false save error.
        }
      }

      return saved;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _runAutoSave() async {
    if (!_isDirty) return;
    _autoSaveTimer?.cancel();
    try {
      await _queuePersist(isManual: false);
    } catch (error) {
      _autoSaveError = error.toString();
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<bool> _onWillPop() async {
    _autoSaveTimer?.cancel();

    // If a checkpoint is already writing to SQLite, wait for it before this
    // route is disposed so newly persisted media cannot be cleaned up early.
    if (_saving) {
      await _saveChain;
    }
    if (!_isDirty) return true;

    try {
      await _queuePersist(isManual: false);
      return !_isDirty;
    } catch (error) {
      if (mounted) {
        _showMessage('Could not autosave this diary page: $error');
      }
      return false;
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    if (_reminderEnabled &&
        (_reminderAt == null || !_reminderAt!.isAfter(DateTime.now()))) {
      _showMessage('Choose a future time for the reminder.');
      return;
    }

    _autoSaveTimer?.cancel();
    try {
      final saved = await _queuePersist(isManual: true);
      if (!mounted || saved == null) return;
      if (widget.embedded) {
        widget.onSaved?.call(saved);
      } else {
        Navigator.pop(context, saved);
      }
    } catch (error) {
      if (!mounted) return;
      _autoSaveError = error.toString();
      setState(() {});
      _showMessage('Could not save diary entry: $error');
    }
  }

  Future<void> _pickEntryDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1970),
      lastDate: DateTime(2200),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (pickedTime == null) return;

    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
    _markDirty();
  }

  Future<void> _pickReminder() async {
    final initial =
        _reminderAt ?? DateTime.now().add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    setState(() {
      _reminderAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _reminderEnabled = true;
    });
    _markDirty();
  }

  Future<void> _showEmojiPicker() async {
    final neutral = context.themeColors.neutral;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: neutral.card,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .48,
          child: EmojiPicker(
            onEmojiSelected: (_, emoji) {
              setState(() => _selectedEmoji = emoji.emoji);
              _markDirty();
              Navigator.pop(sheetContext);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final files = await _imagePicker.pickMultiImage(
        imageQuality: 88,
        limit: 10,
      );
      if (files.isEmpty) return;
      final availableSlots = 10 - _imagePaths.length;
      final selected = files.take(availableSlots);
      final persisted = <String>[];
      for (final file in selected) {
        final path = await DiaryMediaService.persistPickedImage(file);
        persisted.add(path);
        _newMedia.add(path);
      }
      if (mounted) {
        setState(() => _imagePaths.addAll(persisted));
        _markDirty(saveImmediately: true);
      }
    } catch (error) {
      if (mounted) _showMessage('Could not add images: $error');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
      );
      if (file == null) return;
      final path = await DiaryMediaService.persistPickedImage(file);
      _newMedia.add(path);
      if (mounted) {
        setState(() => _imagePaths.add(path));
        _markDirty(saveImmediately: true);
      }
    } catch (error) {
      if (mounted) _showMessage('Could not take photo: $error');
    }
  }

  Future<void> _openDrawingBoard() async {
    final path = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DrawingBoardScreen(existingDrawingPath: _drawingPath),
      ),
    );
    if (path == null || !mounted) return;
    _newMedia.add(path);
    if (_drawingPath != null && _drawingPath != path) {
      _removedMedia.add(_drawingPath!);
    }
    setState(() => _drawingPath = path);
    _markDirty(saveImmediately: true);
  }

  void _addTag() {
    var tag = _tagController.text.trim();
    if (tag.startsWith('#')) tag = tag.substring(1).trim();
    if (tag.isEmpty) return;
    if (!_tags.any((item) => item.toLowerCase() == tag.toLowerCase())) {
      setState(() => _tags.add(tag));
      _markDirty();
    }
    _tagController.clear();
  }

  void _removeImage(String path) {
    setState(() => _imagePaths.remove(path));
    _queueMediaRemoval(path);
    _markDirty(saveImmediately: true);
  }

  void _removeDrawing() {
    final path = _drawingPath;
    if (path == null) return;
    setState(() => _drawingPath = null);
    _queueMediaRemoval(path);
    _markDirty(saveImmediately: true);
  }

  void _queueMediaRemoval(String path) {
    if (_newMedia.remove(path)) {
      unawaited(DiaryMediaService.deleteIfOwned(path));
    } else {
      _removedMedia.add(path);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final accent = Color(_accentColorValue);
    final isEditing = widget.existingEntry != null;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: neutral.background,
        appBar: AppBar(
          backgroundColor: neutral.background,
          automaticallyImplyLeading: !widget.embedded,
          leading: widget.embedded
              ? IconButton(
                  tooltip: 'Back to diary',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              : null,
          title: Text(isEditing ? 'Edit diary page' : 'New diary page'),
          actions: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Center(
              child: _AutoSaveStatus(
                saving: _saving,
                dirty: _isDirty,
                hasSavedEntry: _persistedEntry != null,
                hasError: _autoSaveError != null,
              ),
            ),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DiaryEditorHeader(
                selectedDate: _selectedDate,
                emoji: _selectedEmoji,
                accent: accent,
                onDateTap: _pickEntryDate,
                onEmojiTap: _showEmojiPicker,
              ),
              const SizedBox(height: 16),
              _PaperEditor(
                titleController: _titleController,
                notesController: _notesController,
                neutral: neutral,
              ),
              const SizedBox(height: 16),
              _EditorSection(
                title: 'How was the day?',
                icon: Icons.auto_awesome_rounded,
                child: _DiaryTextField(
                  controller: _gratitudeController,
                  minLines: 2,
                  maxLines: 5,
                  hintText:
                      'A moment, lesson, or thing you are grateful for…',
                ),
              ),
              const SizedBox(height: 16),
              _EditorSection(
                title: 'Context',
                icon: Icons.category_rounded,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _triggers.map((trigger) {
                    return ChoiceChip(
                      label: Text(trigger),
                      selected: _selectedTrigger == trigger,
                      onSelected: (selected) {
                        setState(() {
                          _selectedTrigger = selected ? trigger : null;
                        });
                        _markDirty();
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              _EditorSection(
                title: 'Tags',
                icon: Icons.sell_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _DiaryTextField(
                            controller: _tagController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _addTag(),
                            hintText: 'Add a searchable tag',
                            prefixText: '# ',
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: _addTag,
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                    if (_tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tags.map((tag) {
                          return InputChip(
                            label: Text('#$tag'),
                            onDeleted: () {
                              setState(() => _tags.remove(tag));
                              _markDirty();
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _EditorSection(
                title: 'Photos & drawing',
                icon: Icons.collections_rounded,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _imagePaths.length >= 10 ? null : _pickImages,
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text('Gallery'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _imagePaths.length >= 10 ? null : _takePhoto,
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openDrawingBoard,
                            icon: const Icon(Icons.draw_rounded),
                            label: const Text('Draw'),
                          ),
                        ),
                      ],
                    ),
                    if (_imagePaths.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 112,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imagePaths.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final path = _imagePaths[index];
                            return _MediaPreview(
                              path: path,
                              onRemove: () => _removeImage(path),
                            );
                          },
                        ),
                      ),
                    ],
                    if (_drawingPath != null) ...[
                      const SizedBox(height: 12),
                      _DrawingPreview(
                        path: _drawingPath!,
                        onEdit: _openDrawingBoard,
                        onRemove: _removeDrawing,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _EditorSection(
                title: 'Reminder',
                icon: Icons.notifications_active_rounded,
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Remind me about this entry'),
                      subtitle: Text(
                        _reminderAt == null
                            ? 'Choose a date and time'
                            : DateFormat('EEE, d MMM yyyy • h:mm a')
                                .format(_reminderAt!),
                      ),
                      value: _reminderEnabled,
                      onChanged: (value) async {
                        if (value && _reminderAt == null) {
                          await _pickReminder();
                        } else {
                          setState(() => _reminderEnabled = value);
                          _markDirty(saveImmediately: true);
                        }
                      },
                    ),
                    if (_reminderEnabled)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _pickReminder,
                          icon: const Icon(Icons.schedule_rounded),
                          label: const Text('Change reminder time'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _EditorSection(
                title: 'Page color',
                icon: Icons.palette_rounded,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _accentColors.map((value) {
                    final color = Color(value);
                    final selected = value == _accentColorValue;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _accentColorValue = value);
                        _markDirty();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? neutral.textPrimary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: selected
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.bookmark_added_rounded),
                  label:
                      Text(isEditing ? 'Update diary page' : 'Save diary page'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _AutoSaveStatus extends StatelessWidget {
  const _AutoSaveStatus({
    required this.saving,
    required this.dirty,
    required this.hasSavedEntry,
    required this.hasError,
  });

  final bool saving;
  final bool dirty;
  final bool hasSavedEntry;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neutral = context.themeColors.neutral;

    final String label;
    final IconData icon;
    if (saving) {
      label = 'Saving…';
      icon = Icons.sync_rounded;
    } else if (hasError) {
      label = 'Autosave failed';
      icon = Icons.cloud_off_rounded;
    } else if (dirty) {
      label = 'Saving soon…';
      icon = Icons.cloud_upload_outlined;
    } else if (hasSavedEntry) {
      label = 'Saved';
      icon = Icons.cloud_done_rounded;
    } else {
      label = 'Autosave on';
      icon = Icons.cloud_queue_rounded;
    }

    return Tooltip(
      message: hasError
          ? 'Automatic save failed. Use Save to retry.'
          : 'Diary changes are saved automatically.',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (saving)
            const SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 16, color: neutral.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: neutral.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
