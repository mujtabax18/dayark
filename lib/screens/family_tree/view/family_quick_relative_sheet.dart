import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_tokens.dart';
import '../models/family_tree_models.dart';
import '../services/family_tree_repository.dart';

/// One-step family expansion: create a name and optionally a photo, or link an
/// existing person rather than duplicating them. All roles are relative to the
/// highlighted person and stored using the existing relationship schema.
class FamilyQuickRelativeSheet extends StatefulWidget {
  const FamilyQuickRelativeSheet({
    super.key,
    required this.treeId,
    required this.anchor,
    required this.members,
    required this.relationships,
    required this.repository,
    this.initialRole = 'child',
  });

  final int treeId;
  final FamilyMember anchor;
  final List<FamilyMember> members;
  final List<FamilyRelationship> relationships;
  final FamilyTreeRepository repository;
  final String initialRole;

  @override
  State<FamilyQuickRelativeSheet> createState() => _FamilyQuickRelativeSheetState();
}

class _FamilyQuickRelativeSheetState extends State<FamilyQuickRelativeSheet> {
  final _name = TextEditingController();
  final _picker = ImagePicker();
  String _role = 'child';
  String? _imagePath;
  int? _existingMemberId;
  bool _useExisting = false;
  bool _saving = false;
  bool _shareChildrenWithSpouses = true;
  bool _shareParentsWithSiblings = true;

  static const _roles = <String, String>{
    'parent': 'Parent',
    'child': 'Child',
    'sibling': 'Sibling',
    'spouse': 'Spouse',
    'partner': 'Partner',
    'guardian': 'Guardian',
    'ward': 'Person I care for',
    'other': 'Other relative',
  };

  @override
  void initState() {
    super.initState();
    _role = _roles.containsKey(widget.initialRole) ? widget.initialRole : 'child';
    for (final member in widget.members) {
      if (member.id != widget.anchor.id) {
        _existingMemberId = member.id;
        break;
      }
    }
  }

  List<FamilyMember> get _selectedPersonsParents {
    final parentIds = widget.relationships
        .where((relationship) => relationship.type == 'parent' &&
            relationship.toMemberId == widget.anchor.id)
        .map((relationship) => relationship.fromMemberId)
        .toSet();
    return widget.members.where((person) => parentIds.contains(person.id)).toList();
  }

  int get _sharedChildCount {
    if (!_shareChildrenWithSpouses || _role != 'spouse') return 0;
    final parentIds = <int>{widget.anchor.id};
    if (_useExisting && _existingMemberId != null) {
      parentIds.add(_existingMemberId!);
    }
    return widget.relationships
        .where((relationship) => relationship.type == 'parent' &&
            parentIds.contains(relationship.fromMemberId))
        .map((relationship) => relationship.toMemberId)
        .toSet()
        .length;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 86);
      if (image != null && mounted) setState(() => _imagePath = image.path);
    } catch (error) {
      if (mounted) _message('Could not select a photo: $error');
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_useExisting && _existingMemberId == null) return;
    if (!_useExisting && _name.text.trim().isEmpty) {
      _message('Enter the person’s name.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      int personId;
      if (_useExisting) {
        personId = _existingMemberId!;
        final link = FamilyTreeRepository.relationshipForRole(
          anchorMemberId: widget.anchor.id, relativeMemberId: personId, role: _role,
        );
        await widget.repository.addRelationship(
          treeId: widget.treeId,
          fromMemberId: link.$1,
          toMemberId: link.$2,
          type: link.$3,
          shareChildrenWithSpouses: _shareChildrenWithSpouses,
          shareParentsWithSiblings: _shareParentsWithSiblings,
          siblingParentSourceMemberId: widget.anchor.id,
        );
      } else {
        personId = await widget.repository.createRelative(
          treeId: widget.treeId,
          anchorMemberId: widget.anchor.id,
          fullName: _name.text,
          role: _role,
          imageSourcePath: _imagePath,
          shareChildrenWithSpouses: _shareChildrenWithSpouses,
          shareParentsWithSiblings: _shareParentsWithSiblings,
        );
      }
      if (mounted) Navigator.of(context).pop(personId);
    } catch (error) {
      if (mounted) _message('Could not add relationship: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alternatives = widget.members
        .where((person) => person.id != widget.anchor.id).toList();
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text('Grow the family',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                  IconButton(onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded)),
                ]),
                Text('Add someone connected to ${widget.anchor.fullName}.',
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: _role,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Their relationship to this person',
                    prefixIcon: Icon(Icons.account_tree_outlined)),
                  items: _roles.entries.map((entry) => DropdownMenuItem(
                    value: entry.key, child: Text(entry.value))).toList(),
                  onChanged: _saving ? null : (value) {
                    if (value != null) setState(() => _role = value);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (alternatives.isNotEmpty) ...[
                  Wrap(spacing: 8, children: [
                    ChoiceChip(label: const Text('New person'),
                      selected: !_useExisting, onSelected: _saving ? null : (_) =>
                          setState(() => _useExisting = false)),
                    ChoiceChip(label: const Text('Already in this tree'),
                      selected: _useExisting, onSelected: _saving ? null : (_) =>
                          setState(() => _useExisting = true)),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_useExisting)
                  DropdownButtonFormField<int>(
                    value: _existingMemberId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Choose person'),
                    items: alternatives.map((person) => DropdownMenuItem<int>(
                      value: person.id, child: Text(person.fullName,
                        overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: _saving ? null : (id) => setState(() => _existingMemberId = id),
                  )
                else ...[
                  Row(children: [
                    InkWell(
                      onTap: _saving ? null : _pickImage,
                      borderRadius: BorderRadius.circular(42),
                      child: CircleAvatar(radius: 34,
                        backgroundImage: _imagePath != null && File(_imagePath!).existsSync()
                          ? FileImage(File(_imagePath!)) : null,
                        child: _imagePath == null ? const Icon(Icons.add_a_photo_outlined) : null),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _name,
                          enabled: !_saving,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _save(),
                          decoration: const InputDecoration(
                            labelText: 'Full name *', hintText: 'e.g. Ayesha Ahmed'),
                        ),
                        TextButton.icon(
                          onPressed: _saving ? null : _pickImage,
                          icon: const Icon(Icons.image_outlined, size: 18),
                          label: Text(_imagePath == null ? 'Optional photo' : 'Change photo'),
                        ),
                      ],
                    )),
                  ]),
                  Text('Only a name is required. Add dates, contact details and stories later.',
                    style: theme.textTheme.bodySmall),
                ],
                if (_role == 'sibling' && _selectedPersonsParents.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _shareParentsWithSiblings,
                    onChanged: _saving ? null : (value) =>
                        setState(() => _shareParentsWithSiblings = value),
                    title: const Text('Use the same parents'),
                    subtitle: Text('On by default. Link this sibling to '
                        '${_selectedPersonsParents.map((person) => person.fullName).join(' and ')}. '
                        'The existing parents will be reused, not duplicated.'),
                  ),
                ],
                if (_role == 'child' || _role == 'parent' || _role == 'spouse') ...[
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _shareChildrenWithSpouses,
                    onChanged: _saving ? null : (value) =>
                        setState(() => _shareChildrenWithSpouses = value),
                    title: Text(_role == 'spouse'
                        ? 'Share existing children with this spouse'
                        : 'Link children to both spouses'),
                    subtitle: Text(_role == 'spouse'
                        ? '${_sharedChildCount} existing ${_sharedChildCount == 1 ? 'child' : 'children'} '
                          'will be linked to both parents. No person is duplicated.'
                        : 'On by default. If a parent has a spouse, the same '
                          'child is linked to both parents.'),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (_saving) ...[
                  const LinearProgressIndicator(minHeight: 3),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Saving person and updating family connections…',
                    style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.md),
                ],
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                    ? const SizedBox.square(dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_rounded),
                  label: Text(_saving ? 'Saving…' : _useExisting ? 'Connect person' : 'Add to family'),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
