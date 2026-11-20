part of 'ai_chat_screen.dart';

class _AiChatTextDialog extends StatefulWidget {
  const _AiChatTextDialog({
    required this.title,
    required this.initial,
    required this.action,
    this.note,
  });
  final String title, initial, action;
  final String? note;
  @override
  State<_AiChatTextDialog> createState() => _AiChatTextDialogState();
}

class _AiChatTextDialogState extends State<_AiChatTextDialog> {
  late final _input = TextEditingController(text: widget.initial);
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.note != null) Text(widget.note!),
        TextField(
          controller: _input,
          autofocus: true,
          maxLines:
              widget.title == 'Your instructions' ||
                  widget.title == 'Edit message' ||
                  widget.title == 'Add instructions' ||
                  widget.title == 'Conversation instructions' ||
                  widget.title == 'Next response instructions' ||
                  widget.title == 'Template text' ||
                  widget.title == 'Edit template' ||
                  widget.title == 'Review shortened prompt'
              ? 6
              : 1,
          maxLength: widget.title == 'Rename conversation'
              ? 200
              : (widget.title == 'Move to folder' ||
                    widget.title == 'New folder')
              ? 100
              : null,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _input.text.trim()),
        child: Text(widget.action),
      ),
    ],
  );
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }
}

class _AiEditMessageDialog extends StatefulWidget {
  const _AiEditMessageDialog({required this.message});
  final AiMessage message;
  @override
  State<_AiEditMessageDialog> createState() => _AiEditMessageDialogState();
}

class _AiEditMessageDialogState extends State<_AiEditMessageDialog> {
  late final _input = TextEditingController(text: widget.message.text);
  late final _attachments = List<AiAttachment>.of(widget.message.attachments);
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit message'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Messages after this point will be replaced.'),
        TextField(
          controller: _input,
          autofocus: true,
          maxLines: 6,
          onChanged: (_) => setState(() {}),
        ),
        Wrap(
          children: _attachments
              .map(
                (a) => InputChip(
                  label: Text(a.name ?? 'Attachment'),
                  deleteButtonTooltipMessage: 'Remove attachment',
                  onDeleted: () => setState(() => _attachments.remove(a)),
                ),
              )
              .toList(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _input.text.trim().isEmpty && _attachments.isEmpty
            ? null
            : () => Navigator.pop(
                context,
                AiMessage(
                  role: AiRole.user,
                  text: _input.text.trim(),
                  attachments: _attachments,
                  containsPrivateContext: widget.message.containsPrivateContext,
                ),
              ),
        child: const Text('Save and regenerate'),
      ),
    ],
  );
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }
}
