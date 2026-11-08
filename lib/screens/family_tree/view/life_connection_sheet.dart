import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_tokens.dart';
import '../models/family_tree_models.dart';
import '../models/life_archive_models.dart';
import '../services/life_archive_repository.dart';

/// Add/edit an additional relationship without changing genealogy links.
class LifeConnectionSheet extends StatefulWidget {
  const LifeConnectionSheet({super.key, required this.treeId,
    required this.people, required this.repository, this.anchor, this.connection});
  final int treeId;
  final List<FamilyMember> people;
  final LifeArchiveRepository repository;
  final FamilyMember? anchor;
  final LifeConnection? connection;

  @override
  State<LifeConnectionSheet> createState() => _LifeConnectionSheetState();
}

class _LifeConnectionSheetState extends State<LifeConnectionSheet> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _notes;
  late int? _from, _to;
  late String _type;
  DateTime? _started, _ended;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.connection;
    _from = existing?.fromMemberId ?? widget.anchor?.id ??
        (widget.people.isNotEmpty ? widget.people.first.id : null);
    _to = existing?.toMemberId ?? widget.people
        .where((person) => person.id != _from)
        .map((person) => person.id).firstOrNull;
    _type = existing?.type ?? 'friend';
    _label = TextEditingController(text: existing?.label ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _started = existing?.startedAt;
    _ended = existing?.endedAt;
  }

  @override
  void dispose() {
    _label.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool beginning) async {
    final current = beginning ? _started : _ended;
    final date = await showDatePicker(context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1800), lastDate: DateTime(2200));
    if (mounted && date != null) {
      setState(() { if (beginning) { _started = date; } else { _ended = date; } });
    }
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate() || _busy || _from == null || _to == null) return;
    setState(() => _busy = true);
    try {
      await widget.repository.saveConnection(treeId: widget.treeId,
        fromMemberId: _from!, toMemberId: _to!, type: _type,
        label: _label.text, notes: _notes.text,
        startedAt: _started, endedAt: _ended, id: widget.connection?.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot save connection: $error')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _delete() async {
    final existing = widget.connection;
    if (existing == null || _busy) return;
    final accepted = await showDialog<bool>(context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove connection?'),
        content: const Text('This removes only this connection. Neither person will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Remove')),
        ],
      ));
    if (accepted != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.deleteConnection(widget.treeId, existing.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTwoPeople = widget.people.length >= 2;
    return SafeArea(child: Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
        AppSpacing.lg, MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg),
      child: Form(key: _key, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(widget.connection == null ? 'Add life connection' : 'Edit connection',
              style: Theme.of(context).textTheme.titleLarge)),
            IconButton(onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.close_rounded)),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Text('Friends, colleagues, mentors and personal relationships are separate from family ancestry.',
            style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          if (!hasTwoPeople)
            const Padding(padding: EdgeInsets.all(12),
              child: Text('Add at least two people in the People tab first.')),
          DropdownButtonFormField<int>(
            value: _from,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'From person'),
            items: [for (final person in widget.people)
              DropdownMenuItem(value: person.id, child: Text(person.fullName, overflow: TextOverflow.ellipsis))],
            onChanged: _busy ? null : (id) => setState(() {
              _from = id;
              if (_to == id) _to = widget.people
                  .where((person) => person.id != id).map((person) => person.id).firstOrNull;
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<int>(
            value: _to,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Connected person'),
            items: [for (final person in widget.people.where((p) => p.id != _from))
              DropdownMenuItem(value: person.id, child: Text(person.fullName, overflow: TextOverflow.ellipsis))],
            onChanged: _busy ? null : (id) => setState(() => _to = id),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            value: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Connection type'),
            items: [for (final type in LifeConnection.types.entries)
              DropdownMenuItem(value: type.key, child: Text(type.value))],
            onChanged: _busy ? null : (type) => setState(() => _type = type ?? 'friend'),
          ),
          if (_type == 'custom') ...[
            const SizedBox(height: AppSpacing.sm),
            TextFormField(controller: _label,
              decoration: const InputDecoration(labelText: 'Custom label'),
              validator: (s) => s == null || s.trim().isEmpty ? 'Enter a label' : null),
          ],
          const SizedBox(height: AppSpacing.sm),
          TextFormField(controller: _notes, maxLines: 2,
            decoration: const InputDecoration(labelText: 'Shared story or notes (optional)')),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: 8, children: [
            InputChip(label: Text(_started == null ? 'Connected since' :
                'Since ${DateFormat.yMMMd().format(_started!)}'),
              onPressed: () => _pickDate(true),
              onDeleted: _started == null ? null : () => setState(() => _started = null)),
            InputChip(label: Text(_ended == null ? 'End date (optional)' :
                'Until ${DateFormat.yMMMd().format(_ended!)}'),
              onPressed: () => _pickDate(false),
              onDeleted: _ended == null ? null : () => setState(() => _ended = null)),
          ]),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(onPressed: !hasTwoPeople || _busy ? null : _save,
            icon: const Icon(Icons.link_rounded),
            label: Text(_busy ? 'Saving…' : 'Save connection')),
          if (widget.connection != null)
            TextButton.icon(onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.link_off_rounded), label: const Text('Remove connection')),
        ],
      ))),
    ));
  }
}
