part of 'ai_chat_screen.dart';

extension _AiWorkspaceView on _AiChatScreenState {
  Widget _historyMenuButton() => Builder(
    builder: (context) => IconButton(
      tooltip: 'Conversation history',
      icon: const Icon(Icons.menu_rounded),
      onPressed: () => Scaffold.of(context).openDrawer(),
    ),
  );

  Widget _buildWorkspace(BuildContext context, {required double width}) {
    final chat = _chat;
    if (chat == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('AI Chat'),
          leading: width < 900 ? _historyMenuButton() : null,
        ),
        drawer: width < 900
            ? Drawer(
                child: SafeArea(
                  child: Column(
                    children: [if (!_desktopPlatform) _exitChatTile()],
                  ),
                ),
              )
            : null,
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    TextButton(onPressed: _init, child: const Text('Retry')),
                  ],
                ),
        ),
      );
    }
    final desktop = width >= 900;
    final inspector = desktop && width >= 1180 && _inspector;
    final compact =
        MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom <
        420;
    final theme = Theme.of(context);
    final conversation = chat.active;
    if (!identical(_messageTheme, theme) ||
        _messageBusy != chat.busy ||
        _messageChatId != conversation?.id ||
        _messageCount != conversation?.messages.length) {
      _messageWidgets.clear();
      _messageTheme = theme;
      _messageBusy = chat.busy;
      _messageChatId = conversation?.id;
      _messageCount = conversation?.messages.length;
    }
    return CallbackShortcuts(
      bindings: {
        for (final meta in [false, true]) ...{
          SingleActivator(LogicalKeyboardKey.keyN, control: !meta, meta: meta):
              _newChat,
          SingleActivator(
            LogicalKeyboardKey.keyK,
            control: !meta,
            meta: meta,
          ): () {
            _update(() => _sidebarCollapsed = false);
            _searchFocus.requestFocus();
          },
          SingleActivator(
            LogicalKeyboardKey.keyM,
            control: !meta,
            meta: meta,
            shift: true,
          ): () {
            if (!chat.busy) _chooseProfile();
          },
          SingleActivator(
            LogicalKeyboardKey.keyS,
            control: !meta,
            meta: meta,
            shift: true,
          ): _toggleSidebar,
          SingleActivator(
            LogicalKeyboardKey.keyB,
            control: !meta,
            meta: meta,
            shift: true,
          ): _savedResponses,
          SingleActivator(
            LogicalKeyboardKey.enter,
            control: !meta,
            meta: meta,
          ): () {
            if (chat.busy) {
              _queueDraft();
            } else {
              _send();
            }
          },
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (chat.busy) chat.stop();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: theme.colorScheme.surface,
            scrolledUnderElevation: 0,
            leading: desktop
                ? IconButton(
                    tooltip: 'Toggle sidebar',
                    onPressed: _toggleSidebar,
                    icon: const Icon(Icons.view_sidebar_outlined),
                  )
                : _historyMenuButton(),
            titleSpacing: 0,
            title: TextButton(
              onPressed: chat.busy || _preparing ? null : _chooseProfile,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _profile?.name ?? 'DayArk AI',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                ],
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'New chat',
                onPressed: chat.busy || _preparing ? null : _newChat,
                icon: const Icon(Icons.edit_square, size: 21),
              ),
              if (desktop) ...[
                IconButton(
                  tooltip: 'Chat preferences',
                  onPressed: chat.busy ? null : _chatPreferences,
                  icon: const Icon(Icons.tune_rounded, size: 21),
                ),
                if (desktop)
                  IconButton(
                    tooltip: 'Memory & knowledge',
                    onPressed: chat.busy ? null : _memoryPage,
                    icon: const Icon(Icons.psychology_outlined, size: 21),
                  ),
              ],
              if (desktop)
                IconButton(
                  tooltip: 'AI settings',
                  onPressed: chat.busy ? null : _settingsPage,
                  icon: const Icon(Icons.settings_outlined, size: 21),
                ),
              if (desktop)
                IconButton(
                  tooltip: 'Toggle inspector',
                  onPressed: _toggleInspector,
                  icon: const Icon(Icons.vertical_split_outlined, size: 21),
                ),
              PopupMenuButton<String>(
                tooltip: 'Conversation actions',
                enabled: !chat.busy && !_preparing,
                onSelected: (value) {
                  if (value == 'settings') {
                    _settingsPage();
                  } else if (value == 'preferences') {
                    _chatPreferences();
                  } else if (value == 'memory') {
                    _memoryPage();
                  } else if (value == 'shortcuts') {
                    _shortcuts();
                  } else {
                    _action(value);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'settings',
                    child: Text('AI settings'),
                  ),
                  const PopupMenuItem(
                    value: 'preferences',
                    child: Text('Chat preferences'),
                  ),
                  const PopupMenuItem(
                    value: 'memory',
                    child: Text('Memory & knowledge'),
                  ),
                  const PopupMenuItem(
                    value: 'shortcuts',
                    child: Text('Keyboard shortcuts'),
                  ),
                  if (conversation != null) ...[
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(
                      value: 'pin',
                      child: Text(conversation.pinned ? 'Unpin' : 'Pin'),
                    ),
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(
                        conversation.archived ? 'Unarchive' : 'Archive',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'folder',
                      child: Text('Move to folder'),
                    ),
                    const PopupMenuItem(
                      value: 'json',
                      child: Text('Export JSON (includes attachments)'),
                    ),
                    const PopupMenuItem(
                      value: 'md',
                      child: Text('Export Markdown'),
                    ),
                    const PopupMenuItem(
                      value: 'txt',
                      child: Text('Export text'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ],
              ),
            ],
          ),
          drawer: desktop
              ? null
              : Drawer(child: SafeArea(child: _history(drawer: true))),
          body: Row(
            children: [
              if (desktop && !_sidebarCollapsed) ...[
                SizedBox(
                  width: _sidebarWidth,
                  child: Material(
                    color: theme.colorScheme.surfaceContainerLowest,
                    child: _history(),
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) => _update(
                      () => _sidebarWidth = (_sidebarWidth + details.delta.dx)
                          .clamp(200, 360),
                    ),
                    onHorizontalDragEnd: (_) =>
                        _workspace!.layout(width: _sidebarWidth),
                    child: Container(
                      width: 5,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: .35,
                      ),
                    ),
                  ),
                ),
              ],
              Expanded(
                key: const ValueKey('ai-chat-content'),
                child: Column(
                  children: [
                    if (!compact)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 2, 20, 12),
                        child: Row(
                          children: [
                            Icon(
                              _profile?.kind == AiProviderKind.offline
                                  ? Icons.verified_user_outlined
                                  : Icons.cloud_outlined,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _profile == null
                                    ? 'Choose a model to start'
                                    : _profile!.kind == AiProviderKind.offline
                                    ? 'On device · Private'
                                    : 'Messages are sent to ${_profile!.name}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            if (_profile?.kind == AiProviderKind.offline ||
                                _profile?.kind == AiProviderKind.ollama)
                              const Tooltip(
                                triggerMode: TooltipTriggerMode.tap,
                                message: 'Local model speed depends on the system running it. For faster responses, choose a lighter model; answer quality may be lower.',
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.info_outline, size: 18),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (chat.status != null &&
                        chat.status !=
                            conversation?.messages.lastOrNull?.error &&
                        !compact)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          chat.status!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    Expanded(
                      key: const ValueKey('ai-chat-viewport'),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: conversation == null
                                ? AiChatWelcome(
                                    configured:
                                        _preferences.profiles.isNotEmpty,
                                    onSetup: _settingsPage,
                                    onPrompt: (prompt) {
                                      _composer.text = prompt;
                                      _composerFocus.requestFocus();
                                    },
                                  )
                                : ListView.builder(
                                    key: const ValueKey('ai-chat-message-list'),
                                    controller: _scroll,
                                    reverse: true,
                                    padding: const EdgeInsets.only(bottom: 24),
                                    itemCount: conversation.messages.length,
                                    findChildIndexCallback: (key) {
                                      if (key is! ValueKey<String>) return null;
                                      final index = conversation.messages
                                          .indexWhere((m) => m.id == key.value);
                                      return index < 0
                                          ? null
                                          : conversation.messages.length -
                                                1 -
                                                index;
                                    },
                                    itemBuilder: (_, i) {
                                      final index =
                                          conversation.messages.length - 1 - i;
                                      final message =
                                          conversation.messages[index];
                                      final cached =
                                          _messageWidgets[message.id];
                                      final child =
                                          identical(cached?.$1, message) &&
                                              message.state !=
                                                  AiChatMessageState.pending
                                          ? cached!.$2
                                          : _message(message, index);
                                      _messageWidgets[message.id] = (
                                        message,
                                        child,
                                      );
                                      if (_messageWidgets.length > 100) {
                                        _messageWidgets.remove(
                                          _messageWidgets.keys.first,
                                        );
                                      }
                                      return Center(
                                        key: ValueKey(message.id),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 800,
                                          ),
                                          child: child,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          Positioned(
                            right: 20,
                            bottom: 12,
                            child: ListenableBuilder(
                              listenable: _scroll,
                              builder: (_, _) =>
                                  (_scrollPosition?.pixels ?? 0) < 160
                                  ? const SizedBox.shrink()
                                  : IconButton.filledTonal(
                                      tooltip: 'Scroll to bottom',
                                      onPressed: () =>
                                          _scrollPosition?.animateTo(
                                            0,
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            curve: Curves.easeOut,
                                          ),
                                      icon: const Icon(
                                        Icons.arrow_downward,
                                        size: 20,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (chat.busy && !compact)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              chat.activity ?? 'Preparing conversation…',
                              style: theme.textTheme.bodySmall,
                            ),
                            TextButton(
                              onPressed: () => _redirect(answerNow: true),
                              child: const Text('Answer now'),
                            ),
                            TextButton(
                              onPressed: _redirect,
                              child: const Text('Add instructions'),
                            ),
                          ],
                        ),
                      ),
                    if (chat.queue.isNotEmpty) _queueStrip(),
                    _composerView(compact),
                    if (!compact &&
                        MediaQuery.viewInsetsOf(context).bottom == 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'AI can make mistakes. Check important information.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              if (inspector)
                AiWorkspaceInspector(
                  settings: _preferences.settings,
                  model: _profile?.modelId,
                  local: _profile?.kind == AiProviderKind.offline,
                  message: conversation?.messages.lastOrNull,
                  activity: chat.activity,
                  onSettings: _settingsPage,
                  onInstructions: _instructions,
                  onClose: _toggleInspector,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _memoryPage() => Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => const MemoryScreen()),
  );
  Future<void> _shortcuts() => showDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (context) => AlertDialog(
      title: const Text('Keyboard shortcuts'),
      content: const Text(
        'Ctrl / Cmd + N   New conversation\nCtrl / Cmd + K   Search chats\nCtrl / Cmd + Shift + M   Choose model\nCtrl / Cmd + Shift + B   Saved responses\nCtrl / Cmd + Shift + S   Toggle sidebar\nCtrl / Cmd + Enter   Send or queue\nEscape   Stop generation\nEnter   Follows Enter to send setting\nShift + Enter   New line',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Widget _queueStrip() => SizedBox(
    height: 48,
    child: Row(
      children: [
        if (!_chat!.busy)
          TextButton.icon(
            onPressed: _chat!.sendQueued,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Send queued'),
          ),
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _chat!.queue.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InputChip(
                avatar: i == 0
                    ? null
                    : IconButton(
                        tooltip: 'Move queued message earlier',
                        padding: EdgeInsets.zero,
                        onPressed: () => _chat!.moveQueued(i, i - 1),
                        icon: const Icon(Icons.arrow_upward, size: 16),
                      ),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    '${i + 1}. ${_chat!.queue[i].message.text}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                onPressed: () async {
                  final queued = _chat!.queue[i];
                  final text = await _editText(
                    'Edit queued message',
                    queued.message.text,
                  );
                  final current = _chat!.queue.indexOf(queued);
                  if (text != null && current >= 0) {
                    _chat!.editQueued(current, text);
                  }
                },
                onDeleted: () => _chat!.removeQueued(i),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
