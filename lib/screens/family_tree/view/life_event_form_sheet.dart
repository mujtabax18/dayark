import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_tokens.dart';
import '../models/family_tree_models.dart';
import '../models/life_archive_models.dart';
import '../services/life_archive_repository.dart';

class LifeEventFormSheet extends StatefulWidget {
  const LifeEventFormSheet({super.key, required this.treeId,
    required this.people, required this.repository, this.event, this.initialPersonId});
  final int treeId;
  final List<FamilyMember> people;
  final LifeArchiveRepository repository;
  final LifeEvent? event;
  final int? initialPersonId;

  @override
  State<LifeEventFormSheet> createState() => _LifeEventFormSheetState();
}

class _LifeEventFormSheetState extends State<LifeEventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title, _location, _description;
  late String _type;
  DateTime? _date;
  final Set<int> _attendees = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.event?.title ?? '');
    _location = TextEditingController(text: widget.event?.location ?? '');
    _description = TextEditingController(text: widget.event?.description ?? '');
    _type = widget.event?.type ?? 'milestone';
    _date = widget.event?.eventDate;
    _attendees.addAll(widget.event?.participantIds ?? const []);
    if (widget.initialPersonId != null) _attendees.add(widget.initialPersonId!);
  }

  @override
  void dispose() {
    _title.dispose(); _location.dispose(); _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(1800), lastDate: DateTime(2200));
    if (mounted && date != null) setState(() => _date = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveEvent(treeId: widget.treeId,
        title: _title.text, type: _type,
        description: _description.text, location: _location.text,
        eventDate: _date, participantIds: _attendees.toList(), id: widget.event?.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save event: $error')));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(
    padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
      AppSpacing.lg, MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg),
    child: Form(key: _formKey, child: SingleChildScrollView(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(child: Text(widget.event == null ? 'Add life event' : 'Edit life event',
            style: Theme.of(context).textTheme.titleLarge)),
          IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height: AppSpacing.md),
        TextFormField(controller: _title, textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Event title *',
            hintText: 'Graduation, first job, a wonderful trip…'),
          validator: (s) => s == null || s.trim().isEmpty ? 'Give your event a title.' : null),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(value: _type, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [for (final t in LifeEvent.types.entries)
            DropdownMenuItem(value: t.key, child: Text(t.value))],
          onChanged: _saving ? null : (v) => setState(() => _type = v ?? 'milestone')),
        const SizedBox(height: AppSpacing.sm),
        InputDecorator(decoration: const InputDecoration(labelText: 'When did this happen?'),
          child: Row(children: [
            Expanded(child: InkWell(onTap: _pickDate,
              child: Text(_date == null ? 'Choose a date' : DateFormat.yMMMd().format(_date!)))),
            if (_date != null) IconButton(onPressed: () => setState(() => _date = null),
              icon: const Icon(Icons.close_rounded, size: 18)),
            IconButton(onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_outlined, size: 18)),
          ])),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(controller: _location,
          decoration: const InputDecoration(labelText: 'Location (optional)')),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(controller: _description, maxLines: 3,
          decoration: const InputDecoration(labelText: 'Story / what happened')),
        const SizedBox(height: AppSpacing.md),
        Text('People involved', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        if (widget.people.isEmpty)
          const Text('You can tag people after adding them to the archive.')
        else Wrap(spacing: 7, runSpacing: 2, children: [
          for (final person in widget.people)
            FilterChip(label: Text(person.fullName),
              selected: _attendees.contains(person.id),
              onSelected: (v) => setState(() {
                if (v) { _attendees.add(person.id); } else { _attendees.remove(person.id); }
              })),
        ]),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(onPressed: _saving ? null : _save,
          icon: const Icon(Icons.event_available_outlined),
          label: Text(_saving ? 'Saving…' : 'Save event')),
      ],
    ))),
  ));
}
