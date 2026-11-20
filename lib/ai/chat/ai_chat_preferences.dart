part of 'ai_chat_screen.dart';

extension _AiChatPreferences on _AiChatScreenState {
  String _promptText(List<AiMessage> messages) => messages.isEmpty
      ? 'No messages.'
      : messages
            .asMap()
            .entries
            .map((entry) {
              final message = entry.value;
              return '[${entry.key + 1} · ${message.role.name}]\n${message.text}'
                  '${message.attachments.map((a) => '\n[Attachment: ${a.name ?? 'unnamed'} · ${a.mimeType} · ${a.bytes?.length ?? 0} bytes]').join()}';
            })
            .join('\n\n');

  Widget _promptPanel(String text) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Draft shows instructions, history and your message. Memory and file text '
          'are added during preparation. Latest request shows the prepared messages '
          'for this chat. Providers apply their chat template; local models may trim older history. '
          'Attachments are listed by name, type and size. Extra prompt switches DayArk instructions, '
          'your instructions and language preferences on or off. Opted-in memory is controlled separately.',
        ),
        const SizedBox(height: 16),
        SelectableText(text),
      ],
    ),
  );

  Future<void> _showPrompts() async {
    final settings = _responseSettings();
    final history = (_chat!.active?.messages ?? <AiChatMessage>[])
        .where((m) => m.state == AiChatMessageState.complete)
        .map((m) => m.message);
    final emptyDraft = _composer.text.trim().isEmpty && _attachments.isEmpty;
    final built = const PromptManager().build(
      settings: settings,
      history: history,
      message: AiMessage(
        role: AiRole.user,
        text: emptyDraft ? 'Empty draft' : _composer.text.trim(),
        attachments: _attachments,
      ),
    );
    final draft = emptyDraft ? built.take(built.length - 1).toList() : built;
    final last = _lastPromptChatId == _chat!.active?.id ? _lastPrompt : null;
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) => DefaultTabController(
        length: 2,
        child: AlertDialog(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
          title: const Text('Prompts sent to AI'),
          content: SizedBox(
            width: 700,
            height: 480,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Draft'),
                    Tab(text: 'Latest request'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _promptPanel(_promptText(draft)),
                      _promptPanel(
                        last == null
                            ? 'Send a message to see its prepared request here. This view is kept only while chat is open.'
                            : _promptText(last),
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

  Future<void> _chatPreferences() => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: false,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => StatefulBuilder(
      builder: (context, update) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Chat preferences',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            SwitchListTile.adaptive(
              title: const Text('Automatic paired-device sync'),
              subtitle: const Text(
                'Share AI conversations with your paired devices.',
              ),
              value: _syncEnabled,
              onChanged: (value) async {
                await _chat!.store.setSyncEnabled(value);
                if (!mounted || !context.mounted) return;
                _update(() => _syncEnabled = value);
                update(() {});
              },
            ),
            ListTile(
              title: const Text('Sync shared chats now'),
              leading: const Icon(Icons.sync),
              enabled: _syncEnabled,
              onTap: !_syncEnabled
                  ? null
                  : () {
                      Navigator.pop(context);
                      unawaited(_sync());
                    },
            ),
            SwitchListTile.adaptive(
              title: const Text('Reply-ready notifications'),
              value: _replyNotifications,
              onChanged: (value) async {
                await _chat!.store.setReplyNotificationsEnabled(value);
                if (!mounted || !context.mounted) return;
                _update(() => _replyNotifications = value);
                update(() {});
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}
