import 'package:flutter/material.dart';

class AiChoice {
  const AiChoice(this.id, this.title, {this.subtitle, this.icon});
  final String id, title;
  final String? subtitle;
  final IconData? icon;
}

/// Shared, searchable model/profile selection for chat and settings.
Future<String?> showAiChoicePicker(
  BuildContext context, {
  required String title,
  required List<AiChoice> choices,
  String? selected,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) =>
      _ChoiceSheet(title: title, choices: choices, selected: selected),
);

class _ChoiceSheet extends StatefulWidget {
  const _ChoiceSheet({
    required this.title,
    required this.choices,
    this.selected,
  });
  final String title;
  final List<AiChoice> choices;
  final String? selected;
  @override
  State<_ChoiceSheet> createState() => _ChoiceSheetState();
}

class _ChoiceSheetState extends State<_ChoiceSheet> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final choices = widget.choices.where(
      (c) => '${c.title} ${c.subtitle ?? ''}'.toLowerCase().contains(_query),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search models',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: choices.isEmpty
                    ? const Center(child: Text('No matching models'))
                    : ListView(
                        children: [
                          for (final choice in choices)
                            ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              selected: choice.id == widget.selected,
                              leading: Icon(
                                choice.icon ?? Icons.auto_awesome_outlined,
                              ),
                              title: Text(choice.title),
                              subtitle: choice.subtitle == null
                                  ? null
                                  : Text(choice.subtitle!),
                              trailing: choice.id == widget.selected
                                  ? const Icon(Icons.check_rounded)
                                  : null,
                              onTap: () => Navigator.pop(context, choice.id),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
