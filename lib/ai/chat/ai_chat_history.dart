part of 'ai_chat_screen.dart';

extension _AiHistory on _AiChatScreenState {
  Widget _exitChatTile() => ListTile(
    leading: const Icon(Icons.arrow_back_rounded, size: 20),
    title: const Text('Back to DayArk'),
    onTap: widget.onBack,
  );

  Widget _history({bool drawer = false}) {
    final chat = _chat!;
    final theme = Theme.of(context);
    final visible = chat.conversations
        .where((c) => !_favouritesOnly || c.pinned)
        .toList();
    void closeDrawer() {
      if (drawer) Navigator.pop(context);
    }

    final entries = <Widget>[
      ListTile(
        dense: true,
        leading: const Icon(Icons.star_border, size: 20),
        title: const Text('Favourites'),
        selected: _favouritesOnly,
        onTap: () => _update(() => _favouritesOnly = !_favouritesOnly),
      ),
      ListTile(
        dense: true,
        leading: const Icon(Icons.bookmark_border, size: 20),
        title: const Text('Saved responses'),
        onTap: () {
          closeDrawer();
          _savedResponses();
        },
      ),
      ListTile(
        dense: true,
        leading: const Icon(Icons.library_books_outlined, size: 20),
        title: const Text('Prompt library'),
        onTap: () {
          closeDrawer();
          _promptLibrary();
        },
      ),
      ListTile(
        dense: true,
        leading: const Icon(Icons.memory_outlined, size: 20),
        title: const Text('Models'),
        onTap: chat.busy
            ? null
            : () {
                closeDrawer();
                _modelsPage();
              },
      ),
      ListTile(
        dense: true,
        leading: const Icon(Icons.forum_outlined, size: 20),
        title: const Text('All chats'),
        selected: chat.folder == null && !_favouritesOnly,
        onTap: chat.busy
            ? null
            : () {
                _update(() => _favouritesOnly = false);
                chat.folder = null;
                unawaited(chat.refresh());
              },
      ),
      for (final folder in chat.folders)
        ListTile(
          dense: true,
          title: Text(
            folder.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: const Icon(Icons.folder_outlined, size: 20),
          selected: chat.folder == folder.name,
          trailing: IconButton(
            tooltip: folder.pinned ? 'Unpin folder' : 'Pin folder',
            icon: Icon(
              folder.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              size: 16,
            ),
            onPressed: chat.busy
                ? null
                : () async {
                    await chat.store.saveFolder(
                      folder.name,
                      pinned: !folder.pinned,
                    );
                    await chat.refresh();
                  },
          ),
          onTap: chat.busy
              ? null
              : () {
                  chat.folder = folder.name;
                  unawaited(chat.refresh());
                },
        ),
      const Divider(indent: 16, endIndent: 16),
      SwitchListTile(
        dense: true,
        title: const Text('Archived'),
        value: chat.showArchived,
        onChanged: chat.busy
            ? null
            : (value) {
                chat.showArchived = value;
                unawaited(chat.refresh());
              },
      ),
    ];
    String? previousGroup;
    for (final c in visible) {
      final date = c.updatedAt.toLocal();
      final today = DateUtils.dateOnly(DateTime.now());
      final day = DateUtils.dateOnly(date);
      final group = c.pinned
          ? 'Pinned'
          : day == today
          ? 'Today'
          : day == today.subtract(const Duration(days: 1))
          ? 'Yesterday'
          : 'Earlier';
      if (group != previousGroup) {
        entries.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Text(
              group,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
        previousGroup = group;
      }
      entries.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ListTile(
            dense: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            selected: c.id == chat.active?.id,
            selectedTileColor: theme.colorScheme.surfaceContainerHigh,
            title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: PopupMenuButton<_HistoryAction>(
              tooltip: 'Chat actions: ${c.title}',
              enabled: !chat.busy && !_preparing,
              onSelected: (action) => _historyAction(c, action),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _HistoryAction.pin,
                  child: Text(c.pinned ? 'Unpin chat' : 'Pin chat'),
                ),
                const PopupMenuItem(
                  value: _HistoryAction.move,
                  child: Text('Move to folder'),
                ),
              ],
            ),
            onTap: chat.busy
                ? null
                : () async {
                    await _select(c);
                    if (drawer && mounted) Navigator.pop(context);
                  },
          ),
        ),
      );
    }
    if (visible.isEmpty) {
      entries.add(const ListTile(title: Text('No conversations found')));
    }
    return Column(
      children: [
        if (drawer && !_desktopPlatform) _exitChatTile(),
        ListTile(
          title: Text('DayArk AI', style: theme.textTheme.titleSmall),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'New folder',
                icon: const Icon(Icons.create_new_folder_outlined, size: 19),
                onPressed: chat.busy
                    ? null
                    : () async {
                        final name = await _createFolder();
                        if (name != null) {
                          chat.folder = name;
                          await chat.refresh();
                        }
                      },
              ),
              IconButton(
                tooltip: 'New chat',
                icon: const Icon(Icons.edit_square, size: 19),
                onPressed: chat.busy
                    ? null
                    : () {
                        _newChat();
                        closeDrawer();
                      },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: _search,
            focusNode: _searchFocus,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: 'Search chats and messages',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (q) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 250), () {
                chat.query = q;
                unawaited(chat.refresh());
              });
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (_, index) => entries[index],
          ),
        ),
        const Divider(height: 1),
        ListTile(
          dense: true,
          leading: const Icon(Icons.settings_outlined, size: 19),
          title: const Text('Settings'),
          onTap: chat.busy
              ? null
              : () {
                  closeDrawer();
                  _settingsPage();
                },
        ),
      ],
    );
  }

  Future<void> _modelsPage() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AiLocalModelsPage(
          load: _getLocalModels,
          defaults: _settings!.loadDefaults(),
          selectedId: _profile?.modelId,
        ),
      ),
    );
    if (!mounted || id == null) return;
    final models = _loadedLocalModels;
    if (models == null) return;
    final current = _settings!.load();
    final existing = current.profiles
        .where((p) => p.kind == AiProviderKind.offline && p.modelId == id)
        .firstOrNull;
    final profile =
        existing ??
        AiProviderProfile(
          id: 'local-${const Uuid().v4()}',
          name: models.installed.firstWhere((m) => m.id == id).name,
          kind: AiProviderKind.offline,
          modelId: id,
        );
    final preferences = AiPreferences(
      profiles: [
        for (final p in current.profiles) p,
        if (existing == null) profile,
      ],
      selectedProfileId: profile.id,
      settings: current.settings,
      allowOnlineProcessing: current.allowOnlineProcessing,
      allowPrivateContextOnline: current.allowPrivateContextOnline,
    );
    await _settings!.save(preferences);
    if (mounted) {
      _update(() {
        _preferences = preferences;
        _profileId = profile.id;
      });
    }
  }
}
