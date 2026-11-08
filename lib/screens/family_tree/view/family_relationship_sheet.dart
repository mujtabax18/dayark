import 'package:flutter/material.dart';

import '../../../core/design/app_tokens.dart';
import '../models/family_tree_models.dart';
import '../services/family_tree_repository.dart';

class FamilyRelationshipSheet extends StatefulWidget {
  const FamilyRelationshipSheet({
    super.key,
    required this.treeId,
    required this.member,
    required this.members,
    required this.relationships,
    required this.repository,
  });

  final int treeId;
  final FamilyMember member;
  final List<FamilyMember> members;
  final List<FamilyRelationship> relationships;
  final FamilyTreeRepository repository;

  @override
  State<FamilyRelationshipSheet> createState() => _FamilyRelationshipSheetState();
}

class _FamilyRelationshipSheetState extends State<FamilyRelationshipSheet> {
  late List<FamilyRelationship> _relationships;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _relationships = List.of(widget.relationships);
  }

  FamilyMember? _memberById(int id) {
    for (final member in widget.members) {
      if (member.id == id) return member;
    }
    return null;
  }

  List<FamilyRelationship> get _visibleRelationships => _relationships
      .where((relationship) =>
          relationship.fromMemberId == widget.member.id ||
          relationship.toMemberId == widget.member.id)
      .toList();

  String _relationshipLabel(FamilyRelationship relationship) {
    final selectedId = widget.member.id;
    final isFrom = relationship.fromMemberId == selectedId;
    switch (relationship.type) {
      case 'parent':
        return isFrom ? 'Parent of' : 'Child of';
      case 'guardian':
        return isFrom ? 'Guardian of' : 'Guarded by';
      case 'spouse':
        return 'Spouse';
      case 'partner':
        return 'Partner';
      case 'sibling':
        return 'Sibling';
      default:
        return 'Related to';
    }
  }

  FamilyMember? _otherMember(FamilyRelationship relationship) {
    final otherId = relationship.fromMemberId == widget.member.id
        ? relationship.toMemberId
        : relationship.fromMemberId;
    return _memberById(otherId);
  }

  Future<void> _addRelationship() async {
    final available = widget.members.where((member) => member.id != widget.member.id).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add another family member first.')),
      );
      return;
    }

    bool shareChildrenWithSpouses = true;
    bool shareParentsWithSiblings = true;
    final parentIds = _relationships
        .where((relationship) => relationship.type == 'parent' &&
            relationship.toMemberId == widget.member.id)
        .map((relationship) => relationship.fromMemberId)
        .toSet();
    final parents = widget.members.where((member) => parentIds.contains(member.id)).toList();
    String role = 'parent_of';
    int targetId = available.first.id;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add relationship'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Relationship'),
                  items: const [
                    DropdownMenuItem(value: 'parent_of', child: Text('Is parent of')),
                    DropdownMenuItem(value: 'child_of', child: Text('Is child of')),
                    DropdownMenuItem(value: 'spouse', child: Text('Is spouse of')),
                    DropdownMenuItem(value: 'partner', child: Text('Is partner of')),
                    DropdownMenuItem(value: 'sibling', child: Text('Is sibling of')),
                    DropdownMenuItem(value: 'guardian_of', child: Text('Is guardian of')),
                    DropdownMenuItem(value: 'guarded_by', child: Text('Is guarded by')),
                  ],
                  onChanged: (value) => setDialogState(() => role = value ?? 'parent_of'),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int>(
                  value: targetId,
                  decoration: const InputDecoration(labelText: 'Person'),
                  items: available
                      .map((member) => DropdownMenuItem<int>(value: member.id, child: Text(member.fullName)))
                      .toList(),
                  onChanged: (value) => setDialogState(() => targetId = value ?? available.first.id),
                ),
                if (role == 'sibling' && parents.isNotEmpty)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use the same parents'),
                    subtitle: Text('On by default. The new sibling will also be linked to '
                        '${parents.map((parent) => parent.fullName).join(' and ')}. '
                        'No parent or person is duplicated.'),
                    value: shareParentsWithSiblings,
                    onChanged: (value) =>
                        setDialogState(() => shareParentsWithSiblings = value),
                  ),
                if (role == 'spouse' || role == 'parent_of' || role == 'child_of')
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Link children to both spouses'),
                    subtitle: const Text('On by default. Uses the same child person, not a copy.'),
                    value: shareChildrenWithSpouses,
                    onChanged: (value) => setDialogState(() => shareChildrenWithSpouses = value),
                  ),
              ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result != true || _saving) return;
    setState(() => _saving = true);
    try {
      var fromId = widget.member.id;
      var toId = targetId;
      var type = role;
      switch (role) {
        case 'parent_of':
          type = 'parent';
          break;
        case 'child_of':
          type = 'parent';
          fromId = targetId;
          toId = widget.member.id;
          break;
        case 'guardian_of':
          type = 'guardian';
          break;
        case 'guarded_by':
          type = 'guardian';
          fromId = targetId;
          toId = widget.member.id;
          break;
      }

      await widget.repository.addRelationship(
        treeId: widget.treeId,
        fromMemberId: fromId,
        toMemberId: toId,
        type: type,
        shareChildrenWithSpouses: shareChildrenWithSpouses,
        shareParentsWithSiblings: shareParentsWithSiblings,
        siblingParentSourceMemberId: widget.member.id,
      );
      _relationships = await widget.repository.getRelationships(widget.treeId);
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteRelationship(FamilyRelationship relationship) async {
    await widget.repository.deleteRelationship(relationship.id);
    _relationships = await widget.repository.getRelationships(widget.treeId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleRelationships;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.member.fullName} · Relationships',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(onPressed: () => Navigator.of(context).pop(true), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: visible.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(
                        child: Text(
                          'No relationships added yet.',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final relationship = visible[index];
                        final other = _otherMember(relationship);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(child: Icon(Icons.people_outline_rounded)),
                          title: Text(other?.fullName ?? 'Unknown person'),
                          subtitle: Text(_relationshipLabel(relationship)),
                          trailing: IconButton(
                            tooltip: 'Remove relationship',
                            onPressed: () => _deleteRelationship(relationship),
                            icon: const Icon(Icons.link_off_rounded),
                          ),
                        );
                      },
                    ),
            ),
            if (_saving) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: AppSpacing.sm),
              const Text('Updating connections…'),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _addRelationship,
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('Add relationship'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
