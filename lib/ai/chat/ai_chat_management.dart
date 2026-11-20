part of 'ai_chat_screen.dart';

extension _AiChatManagement on _AiChatScreenState {
  Future<void> _showDiagnostics(AiChatMessage message) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.troubleshoot_rounded),
        title: const Text('Provider response details'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: SelectableText(
              message.diagnostics ??
                  'No provider diagnostics were captured for this response.',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Clipboard.setData(
              ClipboardData(text: message.diagnostics ?? message.error ?? ''),
            ),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy details'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _retry(int index, {bool edit = false}) async {
    final messages = _chat!.active!.messages;
    var user = index;
    while (user >= 0 && messages[user].message.role != AiRole.user) {
      user--;
    }
    if (user < 0) return;
    final original = messages[user].message;
    final message = edit
        ? await showDialog<AiMessage>(
            context: context,
            useRootNavigator: false,
            builder: (_) => _AiEditMessageDialog(message: original),
          )
        : original;
    if (message == null) return;
    await _send(edited: message, retryUserIndex: user);
  }

  Future<void> _sync() async {
    _update(() => _syncing = true);
    try {
      final status =
          await (widget.sync?.call() ??
              ref.read(deviceSyncProvider.notifier).syncAiChats());
      await _chat!.refresh();
      if (_chat!.active != null) await _chat!.select(_chat!.active!.id);
      _notice(status);
    } on AiChatSyncLimit {
      _notice(
        'Shared chats exceed the 32 MiB sync limit. Stop sharing some conversations and retry.',
      );
    } catch (_) {
      _notice(
        'Chat sync failed. Enable chat sync on both paired devices and check the connection.',
      );
    } finally {
      if (mounted) _update(() => _syncing = false);
    }
  }

  Future<String?> _createFolder() async {
    final name = await _editText('New folder', '', action: 'Create folder');
    if (name == null) return null;
    try {
      await _chat!.store.saveFolder(name);
      await _chat!.refresh();
      return name.trim();
    } on FormatException catch (error) {
      _notice(error.message);
      return null;
    }
  }

  Future<String?> _chooseFolder(String current) async {
    final folders = await _chat!.store.folders();
    if (!mounted) return null;
    final selected = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (context) => SimpleDialog(
        title: const Text('Move to folder'),
        children: [
          SizedBox(
            width: 360,
            height: 300,
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: const Text('No folder'),
                  trailing: current.isEmpty ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, ''),
                ),
                for (final folder in folders)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(folder.name),
                    trailing: folder.name == current
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(context, folder.name),
                  ),
                ListTile(
                  leading: const Icon(Icons.create_new_folder_outlined),
                  title: const Text('New folder'),
                  onTap: () => Navigator.pop(context, '\u0000new'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected == '\u0000new') return _createFolder();
    return selected;
  }

  Future<void> _historyAction(
    AiConversation summary,
    _HistoryAction action,
  ) async {
    if (_chat!.busy || _preparing) return;
    try {
      final conversation = await _chat!.store.get(summary.id);
      if (conversation == null || conversation.deleted) return;
      final folder = action == _HistoryAction.move
          ? await _chooseFolder(conversation.folder)
          : null;
      if (action == _HistoryAction.move && folder == null) return;
      await _chat!.store.save(
        conversation.copyWith(
          pinned: action == _HistoryAction.pin ? !conversation.pinned : null,
          folder: folder,
        ),
        expectedRevision: conversation.revision,
      );
      await _chat!.refresh();
    } catch (_) {
      _notice('Unable to update this chat. Please try again.');
    }
  }

  String _elapsed(int milliseconds) {
    final seconds = milliseconds / 1000;
    return seconds < 60
        ? '${seconds.toStringAsFixed(1)}s'
        : '${seconds ~/ 60}m ${(seconds % 60).toStringAsFixed(0)}s';
  }
}
