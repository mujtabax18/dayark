part of 'ai_chat_screen.dart';

extension _AiLibrary on _AiChatScreenState {
  Future<void> _savedResponses() async {
    final lists = await Future.wait([
      _chat!.store.list(),
      _chat!.store.list(archived: true),
    ]);
    final chats = lists.expand((c) => c).toList();
    if (!mounted) return;
    var query = '';
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Saved responses'),
          content: SizedBox(
            width: 640,
            height: 480,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search saved responses and tags',
                  ),
                  onChanged: (text) => update(() => query = text.toLowerCase()),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      for (final chat in chats)
                        for (final message in chat.messages.where(
                          (m) =>
                              m.bookmarked &&
                              '${m.message.text} ${m.tags.join(' ')} ${m.note}'
                                  .toLowerCase()
                                  .contains(query),
                        ))
                          Card.outlined(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    chat.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    message.message.text,
                                    maxLines: 6,
                                  ),
                                  if (message.tags.isNotEmpty)
                                    Text(message.tags.join(' · ')),
                                  if (message.note.isNotEmpty)
                                    Text(message.note),
                                  Wrap(
                                    children: [
                                      TextButton(
                                        onPressed: () => Clipboard.setData(
                                          ClipboardData(
                                            text: message.message.text,
                                          ),
                                        ),
                                        child: const Text('Copy'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            SharePlus.instance.share(
                                              ShareParams(
                                                text: message.message.text,
                                              ),
                                            ),
                                        child: const Text('Share / export'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          await _select(chat);
                                        },
                                        child: const Text('Open conversation'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          if (_chat!.busy) return;
                                          final latest = await _chat!.store.get(
                                            chat.id,
                                          );
                                          if (latest == null) return;
                                          await _chat!.store.save(
                                            latest.copyWith(
                                              messages: latest.messages.map(
                                                (m) => m.id == message.id
                                                    ? m.copyWith(
                                                        bookmarked: false,
                                                      )
                                                    : m,
                                              ),
                                            ),
                                            expectedRevision: latest.revision,
                                          );
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        },
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      if (!chats.any(
                        (c) => c.messages.any((m) => m.bookmarked),
                      ))
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Bookmark an answer to keep it here.'),
                        ),
                    ],
                  ),
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
      ),
    );
  }

  Future<void> _promptLibrary() async {
    var items = _workspace!.templates;
    var query = '';
    Future<void> persist() => _workspace!.saveTemplates(items);
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Prompt library'),
          content: SizedBox(
            width: 620,
            height: 480,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search templates',
                  ),
                  onChanged: (value) =>
                      update(() => query = value.toLowerCase()),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final item
                          in [...items]..sort(
                            (a, b) => (b['favourite'] == true ? 1 : 0)
                                .compareTo(a['favourite'] == true ? 1 : 0),
                          ))
                        if ('${item['title']} ${item['category']} ${item['text']}'
                            .toLowerCase()
                            .contains(query))
                          ListTile(
                            title: Text(item['title'] as String),
                            subtitle: Text(
                              item['category'] as String? ?? 'General',
                            ),
                            leading: IconButton(
                              tooltip: 'Favourite template',
                              icon: Icon(
                                item['favourite'] == true
                                    ? Icons.star
                                    : Icons.star_border,
                              ),
                              onPressed: () async {
                                item['favourite'] = item['favourite'] != true;
                                await persist();
                                update(() {});
                              },
                            ),
                            onTap: () {
                              _composer.text = item['text'] as String;
                              Navigator.pop(context);
                              _composerFocus.requestFocus();
                            },
                            trailing: PopupMenuButton<int>(
                              onSelected: (value) async {
                                if (value == 0) {
                                  final text = await _editText(
                                    'Edit template',
                                    item['text'] as String,
                                  );
                                  if (text != null) item['text'] = text;
                                } else if (value == 1) {
                                  items.add({
                                    ...item,
                                    'id': const Uuid().v4(),
                                    'title': '${item['title']} (copy)',
                                  });
                                } else {
                                  items.remove(item);
                                }
                                await persist();
                                if (context.mounted) update(() {});
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 0, child: Text('Edit')),
                                PopupMenuItem(
                                  value: 1,
                                  child: Text('Duplicate'),
                                ),
                                PopupMenuItem(value: 2, child: Text('Delete')),
                              ],
                            ),
                          ),
                      if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Create a reusable prompt, or insert one of the starter templates below.',
                          ),
                        ),
                      for (final starter in const [
                        (
                          'Coding',
                          'Review this code for correctness and explain improvements:\n',
                        ),
                        (
                          'Writing',
                          'Rewrite the following professionally, preserving its meaning:\n',
                        ),
                        (
                          'Summarization',
                          'Summarize the key points and action items:\n',
                        ),
                        (
                          'Translation',
                          'Translate the following into [language]:\n',
                        ),
                        (
                          'Planning',
                          'Create a practical step-by-step plan for:\n',
                        ),
                        (
                          'Learning',
                          'Explain this topic simply, with an example:\n',
                        ),
                      ])
                        ListTile(
                          leading: const Icon(Icons.auto_awesome_outlined),
                          title: Text(starter.$1),
                          onTap: () {
                            _composer.text = starter.$2;
                            Navigator.pop(context);
                            _composerFocus.requestFocus();
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create template'),
              onPressed: () async {
                final title = await _editText('Template name', '');
                if (!mounted || title == null || title.isEmpty) return;
                final text = await _editText('Template text', _composer.text);
                if (!mounted || text == null || text.isEmpty) return;
                final category = await _editText(
                  'Template category',
                  'General',
                );
                if (!mounted || category == null) return;
                items.add({
                  'id': const Uuid().v4(),
                  'title': title,
                  'text': text,
                  'category': category,
                });
                try {
                  await persist();
                  if (context.mounted) update(() {});
                } catch (_) {
                  items.removeLast();
                  if (mounted) {
                    _notice(
                      'Unable to save template. Keep up to 100 templates.',
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _responseNote(AiChatMessage message) async {
    final note = await _editText('Response note', message.note);
    if (!mounted || note == null) return;
    final tags = await _editText(
      'Tags, separated by commas',
      message.tags.join(', '),
    );
    if (!mounted || tags == null) return;
    await _chat!.bookmark(
      message.id,
      saved: true,
      note: note,
      tags: tags
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .take(20)
          .toList(),
    );
  }
}
