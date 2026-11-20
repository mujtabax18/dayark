part of 'ai_chat_screen.dart';

extension _AiMessageView on _AiChatScreenState {
  Widget _message(AiChatMessage m, int index) {
    final assistant = m.message.role == AiRole.assistant;
    final last = index == _chat!.active!.messages.length - 1;
    final scheme = Theme.of(context).colorScheme;
    final thoughts = m.thinking ?? (last ? _chat!.thinkingText : '');
    return Align(
      alignment: assistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 768),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          crossAxisAlignment: assistant
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            if (assistant)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 6),
                child: Text(
                  'DayArk${m.model == null ? '' : ' · ${m.model}'}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: assistant
                    ? Colors.transparent
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (thoughts.isNotEmpty)
                    Material(
                      key: ValueKey('thinking-${m.id}'),
                      color: Colors.transparent,
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        initiallyExpanded:
                            m.state == AiChatMessageState.pending,
                        minTileHeight: 32,
                        title: Text(
                          _chat!.activity == 'Thinking…'
                              ? 'Thinking…'
                              : 'Model thinking',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 240),
                            child: SingleChildScrollView(
                              child: AiResponseText(
                                data: thoughts,
                                live: m.state == AiChatMessageState.pending,
                                maxHeight: 220,
                                selectable: true,
                                styleSheet:
                                    MarkdownStyleSheet.fromTheme(
                                      Theme.of(context),
                                    ).copyWith(
                                      p: Theme.of(context).textTheme.bodySmall,
                                    ),
                                imageBuilder: (_, _, _) =>
                                    const Text('[Image omitted]'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (m.state == AiChatMessageState.pending &&
                      m.message.text == '…')
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _chat!.activity ?? 'Waiting for model…',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    )
                  else if (m.state == AiChatMessageState.failed)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.error ??
                                'The provider could not complete this reply.',
                            style: TextStyle(color: scheme.onErrorContainer),
                          ),
                        ],
                      ),
                    )
                  else if (m.message.text.isNotEmpty)
                    AiResponseText(
                      key: ValueKey('answer-${m.id}'),
                      data: m.message.text,
                      live: m.state == AiChatMessageState.pending,
                      selectable: true,
                      // Model-generated remote images must never trigger hidden network requests.
                      imageBuilder: (uri, title, alt) =>
                          Text('[Image: ${alt ?? title ?? uri.toString()}]'),
                      onTapLink: (text, href, title) async {
                        final uri = Uri.tryParse(href ?? '');
                        if (uri?.scheme == 'dayark-source') {
                          final memory = await sharedMemoryManager();
                          if (!mounted) return;
                          await showMemorySource(
                            context,
                            memory,
                            uri!.path,
                            hash: uri.queryParameters['hash'],
                            offset: int.tryParse(
                              uri.queryParameters['offset'] ?? '',
                            ),
                          );
                          return;
                        }
                        if (uri != null &&
                            ['https', 'http'].contains(uri.scheme) &&
                            uri.userInfo.isEmpty) {
                          final yes = await showDialog<bool>(
                            context: context,
                            useRootNavigator: false,
                            builder: (context) => AlertDialog(
                              title: const Text('Open external link?'),
                              content: Text(uri.toString()),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Open'),
                                ),
                              ],
                            ),
                          );
                          if (yes == true) {
                            launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        }
                      },
                    ),
                  ...m.message.attachments.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: a.kind == AiAttachmentKind.image
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Image.memory(
                                  a.bytes!,
                                  height: 160,
                                  cacheHeight: 320,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.broken_image),
                                ),
                                Text(a.name ?? 'Image'),
                              ],
                            )
                          : Text(
                              '📎 ${a.name ?? 'Document'} · ${(a.bytes!.length / 1024).toStringAsFixed(0)} KiB',
                            ),
                    ),
                  ),
                  if (m.error != null &&
                      m.state != AiChatMessageState.failed &&
                      m.message.text != m.error)
                    Text(m.error!),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: assistant ? WrapAlignment.start : WrapAlignment.end,
                spacing: 2,
                children: [
                  if (m.state == AiChatMessageState.pending ||
                      m.state == AiChatMessageState.stopped ||
                      (assistant && m.thinkingOnly))
                    Text(
                      m.state == AiChatMessageState.pending
                          ? 'Generating · '
                          : m.state == AiChatMessageState.stopped
                          ? 'Stopped · '
                          : 'Model stopped after thinking; no final answer. ',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  Text(
                    '${DateFormat('MMM d, h:mm a').format(m.createdAt.toLocal())}${m.elapsedMilliseconds == null ? '' : ' · ${_elapsed(m.elapsedMilliseconds!)} response'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  IconButton(
                    tooltip: m.message.text.isEmpty && thoughts.isNotEmpty
                        ? 'Copy thoughts'
                        : 'Copy message',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Clipboard.setData(
                      ClipboardData(
                        text: m.message.text.isEmpty
                            ? thoughts
                            : m.message.text,
                      ),
                    ),
                    icon: const Icon(Icons.copy_outlined, size: 17),
                  ),
                  if (!assistant)
                    IconButton(
                      tooltip: 'Edit message',
                      visualDensity: VisualDensity.compact,
                      onPressed: _chat!.busy || _preparing
                          ? null
                          : () => _retry(index, edit: true),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                  if (assistant && last)
                    IconButton(
                      tooltip: m.state == AiChatMessageState.complete
                          ? 'Regenerate response'
                          : 'Retry response',
                      visualDensity: VisualDensity.compact,
                      onPressed: _chat!.busy || _preparing
                          ? null
                          : () => _retry(index),
                      icon: const Icon(Icons.refresh_rounded, size: 19),
                    ),
                  if (assistant && m.state != AiChatMessageState.pending) ...[
                    IconButton(
                      tooltip: m.bookmarked
                          ? 'Remove bookmark'
                          : 'Bookmark response',
                      visualDensity: VisualDensity.compact,
                      onPressed: _chat!.busy
                          ? null
                          : () => _chat!.bookmark(m.id),
                      icon: Icon(
                        m.bookmarked ? Icons.bookmark : Icons.bookmark_border,
                        size: 18,
                      ),
                    ),
                    if (last)
                      IconButton(
                        tooltip: 'Continue response',
                        visualDensity: VisualDensity.compact,
                        onPressed: _chat!.busy || _preparing ? null : _continue,
                        icon: const Icon(Icons.play_arrow_outlined, size: 19),
                      ),
                    PopupMenuButton<int>(
                      tooltip: 'Response actions',
                      enabled: !_chat!.busy && !_preparing,
                      onSelected: (action) async {
                        if (action == 0) await _responseNote(m);
                        if (action == 1) {
                          await SharePlus.instance.share(
                            ShareParams(text: m.message.text),
                          );
                        }
                        if (action == 2) await _chat!.branch(index);
                        if (action == 3) await _versions(m);
                        if (action >= 10) {
                          final instruction = [
                            'Shorten the previous answer.',
                            'Expand the previous answer.',
                            'Explain the previous answer simply.',
                            'Rewrite the previous answer professionally.',
                            'Provide code for the previous answer.',
                          ][action - 10];
                          await _send(
                            edited: AiMessage(
                              role: AiRole.user,
                              text: instruction,
                            ),
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 0,
                          child: Text('Tags and note'),
                        ),
                        const PopupMenuItem(
                          value: 1,
                          child: Text('Share / export response'),
                        ),
                        const PopupMenuItem(
                          value: 2,
                          child: Text('Branch conversation here'),
                        ),
                        if (m.versions.isNotEmpty)
                          PopupMenuItem(
                            value: 3,
                            child: Text(
                              'Previous versions (${m.versions.length})',
                            ),
                          ),
                        for (final item in const [
                          (10, 'Shorten'),
                          (11, 'Expand'),
                          (12, 'Simplify'),
                          (13, 'Rewrite professionally'),
                          (14, 'Generate code'),
                        ])
                          PopupMenuItem(value: item.$1, child: Text(item.$2)),
                      ],
                      icon: const Icon(Icons.more_horiz, size: 18),
                    ),
                  ],
                  if (assistant &&
                      (m.finishReason == 'length' ||
                          m.finishReason == 'max_tokens'))
                    const Text('Output limit reached · Continue for more'),
                  if (m.state == AiChatMessageState.failed)
                    IconButton(
                      tooltip: 'Response error details',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showDiagnostics(m),
                      icon: Icon(
                        Icons.error_outline_rounded,
                        size: 19,
                        color: scheme.error,
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

  Future<void> _versions(AiChatMessage message) => showDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (context) => AlertDialog(
      title: const Text('Previous response versions'),
      content: SizedBox(
        width: 640,
        height: 480,
        child: ListView(
          children: [
            for (var i = 0; i < message.versions.length; i++)
              ExpansionTile(
                title: Text('Version ${i + 1}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(message.versions[i]),
                  ),
                  TextButton(
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: message.versions[i]),
                    ),
                    child: const Text('Copy version'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _chat!.restoreVersion(message.id, i);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Make current version'),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
