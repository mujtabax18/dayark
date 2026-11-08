import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_tokens.dart';
import '../models/family_tree_models.dart';
import '../models/life_archive_models.dart';
import '../services/family_tree_repository.dart';

/// Each memory is an album: title, date, story, one or more photos and any
/// number of tagged people. Existing one-photo memories remain editable.
class FamilyMemoryFormSheet extends StatefulWidget {
  const FamilyMemoryFormSheet({
    super.key,
    required this.treeId,
    required this.members,
    this.events = const [],
    required this.repository,
    this.memory,
    this.initialMemberId,
    this.initialEventId,
  });

  final int treeId;
  final List<FamilyMember> members;
  final List<LifeEvent> events;
  final FamilyTreeRepository repository;
  final FamilyMemory? memory;
  final int? initialMemberId;
  final int? initialEventId;

  @override
  State<FamilyMemoryFormSheet> createState() => _FamilyMemoryFormSheetState();
}

class _FamilyMemoryFormSheetState extends State<FamilyMemoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _title;
  late final TextEditingController _description;
  final _selectedMemberIds = <int>{};
  final _pendingPhotos = <String>[];
  final _removedPhotoIds = <int>{};
  DateTime? _memoryDate;
  int? _eventId;
  bool _removeCover = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.memory?.title ?? '');
    _description = TextEditingController(text: widget.memory?.description ?? '');
    _memoryDate = widget.memory?.memoryDate;
    _eventId = widget.memory?.eventId ?? widget.initialEventId;
    if (widget.memory != null) {
      _selectedMemberIds.addAll(widget.memory!.linkedMemberIds);
    } else if (widget.initialMemberId != null) {
      _selectedMemberIds.add(widget.initialMemberId!);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final images = await _picker.pickMultiImage(
      imageQuality: 82, maxWidth: 1920,
    );
    if (!mounted || images.isEmpty) return;
    setState(() {
      for (final image in images) {
        if (!_pendingPhotos.contains(image.path)) _pendingPhotos.add(image.path);
      }
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _memoryDate ?? DateTime.now(),
      firstDate: DateTime(1800),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) setState(() => _memoryDate = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final selected = _selectedMemberIds.toList()..sort();
      // Keep the current primary link when possible, so old references remain
      // stable when the user edits the rest of the people in an album.
      final previousPrimary = widget.memory?.memberId;
      final primaryId = previousPrimary != null && selected.contains(previousPrimary)
          ? previousPrimary : (selected.isEmpty ? null : selected.first);
      if (widget.memory == null) {
        await widget.repository.createMemory(
          treeId: widget.treeId,
          memberId: primaryId,
          participantIds: selected,
          title: _title.text,
          description: _description.text,
          memoryDate: _memoryDate,
          eventId: _eventId,
          imageSourcePaths: _pendingPhotos,
        );
      } else {
        await widget.repository.updateMemory(
          memoryId: widget.memory!.id,
          memberId: primaryId,
          participantIds: selected,
          title: _title.text,
          description: _description.text,
          memoryDate: _memoryDate,
          eventId: _eventId,
          mediaPath: _removeCover ? null : widget.memory!.mediaPath,
          removedPhotoIds: _removedPhotoIds.toList(),
          imageSourcePaths: _pendingPhotos,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the album: $error')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final original = widget.memory;
    final imageEntries = <({String path, int? id, bool legacy, bool pending})>[
      if (!_removeCover && original?.mediaPath != null)
        (path: original!.mediaPath!, id: null, legacy: true, pending: false),
      if (original != null)
        ...original.photos.where((p) => !_removedPhotoIds.contains(p.id))
          .map((p) => (path: p.path, id: p.id, legacy: false, pending: false)),
      ..._pendingPhotos.map((path) => (path: path, id: null, legacy: false, pending: true)),
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(original == null ? 'Create photo album' : 'Edit photo album',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                  IconButton(onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded)),
                ]),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Album title *',
                    hintText: 'Birthday party, family dinner, summer 2026…',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter a title.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: AppRadius.small,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date of this memory',
                      suffixIcon: _memoryDate == null
                          ? const Icon(Icons.calendar_today_outlined, size: 18)
                          : IconButton(onPressed: () => setState(() => _memoryDate = null),
                              icon: const Icon(Icons.close_rounded, size: 18)),
                    ),
                    child: Text(_memoryDate == null ? 'Choose a date (optional)'
                        : DateFormat.yMMMd().format(_memoryDate!)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (widget.events.isNotEmpty) ...[
                  DropdownButtonFormField<int?>(
                    value: _eventId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Related life event (optional)'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('No event linked')),
                      ...widget.events.map((e) => DropdownMenuItem<int?>(
                        value: e.id, child: Text(e.title, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (id) => setState(() => _eventId = id),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text('People in this memory', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                if (widget.members.isEmpty)
                  const Text('Add people to your tree to tag them in albums.')
                else
                  Wrap(
                    spacing: 8, runSpacing: 4,
                    children: widget.members.map((person) => FilterChip(
                      label: Text(person.fullName, overflow: TextOverflow.ellipsis),
                      selected: _selectedMemberIds.contains(person.id),
                      onSelected: (value) => setState(() {
                        if (value) { _selectedMemberIds.add(person.id); }
                        else { _selectedMemberIds.remove(person.id); }
                      }),
                    )).toList(),
                  ),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Expanded(child: Text('Photos (${imageEntries.length})',
                    style: Theme.of(context).textTheme.titleSmall)),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickPhotos,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add photos'),
                  ),
                ]),
                const SizedBox(height: AppSpacing.xs),
                if (imageEntries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Choose several photos to tell the story of this day or event.',
                      style: Theme.of(context).textTheme.bodySmall),
                  )
                else
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: imageEntries.map((item) => SizedBox(
                      width: 94, height: 104,
                      child: Stack(children: [
                        Positioned.fill(top: 10, child: ClipRRect(
                          borderRadius: AppRadius.small,
                          child: Image.file(File(item.path), fit: BoxFit.cover,
                            cacheWidth: 300,
                            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined))),
                        )),
                        Positioned(top: 0, right: 0, child: IconButton.filledTonal(
                          tooltip: 'Remove photo',
                          iconSize: 16,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          padding: EdgeInsets.zero,
                          onPressed: _saving ? null : () => setState(() {
                            if (item.pending) _pendingPhotos.remove(item.path);
                            else if (item.legacy) _removeCover = true;
                            else if (item.id != null) _removedPhotoIds.add(item.id!);
                          }),
                          icon: const Icon(Icons.close_rounded),
                        )),
                      ]),
                    )).toList(),
                  ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _description,
                  minLines: 3, maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Story / notes', alignLabelWithHint: true,
                    hintText: 'Where was it? What happened? Who was there?',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving ? const SizedBox.square(dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save album'),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
