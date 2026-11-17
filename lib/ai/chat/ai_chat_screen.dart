import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../services/device_sync/device_sync_service.dart';
import '../../screens/navigation/widgets/desktop_navigation_scope.dart';
import '../../utlis/app_router.dart';
import '../core/ai_attachments.dart';
import '../models/ai_models.dart';
import '../settings/ai_preferences.dart';
import '../settings/ai_configured_assistant.dart';
import '../settings/ai_settings_screen.dart';
import '../settings/ai_settings_store.dart';
import 'ai_chat_controller.dart';
import 'ai_chat_notifications.dart';
import 'ai_chat_store.dart';
import 'ai_conversation.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({
    super.key,
    this.store,
    this.settings,
    this.engine,
    this.sync,
  });
  final AiChatStore? store;
  final AiSettingsStore? settings;
  final AiChatStream? engine;
  final Future<String> Function()? sync;
  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen>
    with WidgetsBindingObserver {
  AiChatController? _chat;
  AiSettingsStore? _settings;
  AiPreferences _preferences = AiPreferences();
  final _composer = TextEditingController(), _search = TextEditingController();
  final _scroll = ScrollController();
  final _attachments = <AiAttachment>[];
  String? _profileId, _error;
  bool _syncEnabled = false, _syncing = false, _replyNotifications = true;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
  }

  Future<void> _init() async {
    try {
      final store = widget.store ?? await sharedAiChatStore();
      final settings =
          widget.settings ??
          AiSettingsStore(preferences: await SharedPreferences.getInstance());
      final enabled = await store.syncEnabled;
      final notifications = await store.replyNotificationsEnabled;
      if (!mounted) return;
      _settings = settings;
      _preferences = settings.load();
      _profileId = _preferences.selectedProfileId;
      final assistant = AiConfiguredAssistant(settings);
      _chat = AiChatController(
        store: store,
        engine:
            widget.engine ??
            ({
              required message,
              required history,
              required profileId,
              required cancellationToken,
            }) => assistant.stream(
              message: message,
              history: history,
              profileId: profileId,
              cancellationToken: cancellationToken,
            ),
      );
      _chat!.addListener(_changed);
      _syncEnabled = enabled;
      _replyNotifications = notifications;
      await _chat!.refresh();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Unable to open AI conversations. Check local storage.',
        );
      }
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (_chat!.busy &&
        _scroll.hasClients &&
        _scroll.position.maxScrollExtent - _scroll.offset < 200) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  AiProviderProfile? get _profile =>
      _preferences.profiles.where((p) => p.id == _profileId).firstOrNull;
  Future<void> _settingsPage() async {
    final desktop = DesktopNavigationScope.maybeOf(context);
    if (MediaQuery.sizeOf(context).width >= 1100 && desktop != null) {
      desktop.onOpenRoute(RoutesStr.aiSettings);
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => AiSettingsScreen(store: _settings)),
    );
    if (!mounted) return;
    setState(() {
      _preferences = _settings!.load();
      if (_profile == null) _profileId = _preferences.selectedProfileId;
    });
  }

  Future<void> _select(AiConversation c) async {
    await _chat!.select(c.id);
    if (!mounted) return;
    setState(() {
      _profileId =
          _preferences.profiles.any((p) => p.id == _chat!.active?.profileId)
          ? _chat!.active!.profileId
          : _preferences.selectedProfileId;
      _attachments.clear();
      _composer.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<String?> _editText(
    String title,
    String initial, {
    String action = 'Save',
    String? note,
  }) => showDialog<String>(
    context: context,
    builder: (_) => _AiChatTextDialog(
      title: title,
      initial: initial,
      action: action,
      note: note,
    ),
  );

  Future<void> _action(String action) async {
    final chat = _chat!;
    if (chat.busy) return;
    final c = chat.active;
    try {
      switch (action) {
        case 'rename':
          final name = await _editText('Rename conversation', c!.title);
          if (name?.isNotEmpty ?? false) await chat.update(title: name);
        case 'folder':
          final name = await _editText(
            'Move to folder',
            c!.folder,
            note: 'Leave blank to remove the folder.',
          );
          if (name != null) await chat.update(folder: name);
        case 'pin':
          await chat.update(pinned: !c!.pinned);
        case 'archive':
          await chat.update(archived: !c!.archived);
        case 'delete':
          final yes = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete conversation?'),
              content: const Text(
                'Messages and attachments will be removed. Shared deletion will sync to opted-in devices.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (yes == true) await chat.remove();
        case 'json':
        case 'md':
        case 'txt':
          final bytes = Uint8List.fromList(
            utf8.encode(chat.store.export(c!, action)),
          );
          await SharePlus.instance.share(
            ShareParams(
              files: [
                XFile.fromData(
                  bytes,
                  mimeType: action == 'json'
                      ? 'application/json'
                      : 'text/plain',
                ),
              ],
              fileNameOverrides: ['dayark-chat-${c.id}.$action'],
              sharePositionOrigin: _shareOrigin,
            ),
          );
      }
    } catch (_) {
      _notice('Unable to update or export this conversation.');
    }
  }

  Rect? get _shareOrigin {
    final render = context.findRenderObject();
    return render is RenderBox
        ? render.localToGlobal(Offset.zero) & render.size
        : null;
  }

  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _pick() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'pdf', 'txt', 'md'],
      );
      if (result.isEmpty || !mounted) return;
      if (_attachments.length + result.length > 8) {
        throw const FormatException('Too many attachments.');
      }
      final picked = <AiAttachment>[];
      for (final file in result) {
        if (await file.length() > aiMaxAttachmentBytes) {
          throw const FormatException('Attachment too large.');
        }
        final buffer = BytesBuilder(copy: false);
        await for (final chunk in file.readAsByteStream()) {
          if (buffer.length + chunk.length > aiMaxAttachmentBytes) {
            throw const FormatException('Attachment too large.');
          }
          buffer.add(chunk);
        }
        final bytes = buffer.takeBytes();
        final mime = file.extension?.toLowerCase() == 'md'
            ? 'text/markdown'
            : file.extension?.toLowerCase() == 'txt'
            ? 'text/plain'
            : lookupMimeType(file.name, headerBytes: bytes.take(32).toList());
        final id = const Uuid().v4();
        final a = AiAttachment(
          id: id,
          uri: Uri(scheme: 'attachment', path: id),
          mimeType: mime ?? 'application/octet-stream',
          kind: mime?.startsWith('image/') == true
              ? AiAttachmentKind.image
              : AiAttachmentKind.document,
          name: file.name,
          bytes: bytes,
        );
        validateAiAttachment(a);
        picked.add(a);
      }
      final total = [..._attachments, ...picked];
      if (total.fold<int>(0, (sum, a) => sum + a.bytes!.length) >
          aiMaxRequestAttachmentBytes) {
        throw const FormatException('Attachments too large.');
      }
      if (mounted) setState(() => _attachments.addAll(picked));
    } catch (_) {
      _notice(
        'Attach up to 8 PNG/JPEG/WebP/PDF/TXT/Markdown files, 8 MiB each and 16 MiB total. UTF-8 text is limited to 256 KiB.',
      );
    }
  }

  Future<void> _send({AiMessage? edited, int? retryUserIndex}) async {
    if (_chat!.busy ||
        (edited == null &&
            _composer.text.trim().isEmpty &&
            _attachments.isEmpty)) {
      return;
    }
    final message =
        edited ??
        AiMessage(
          role: AiRole.user,
          text: _composer.text.trim(),
          attachments: _attachments,
        );
    if (_profile == null) {
      _notice('Create a provider profile in AI settings first.');
      return;
    }
    if (edited == null) {
      FocusScope.of(context).unfocus();
    }
    final accepted = await _chat!.send(
      message,
      profileId: _profileId,
      provider: _profile!.kind.name,
      model: _profile!.modelId,
      retryUserIndex: retryUserIndex,
    );
    if (accepted && edited == null && mounted) {
      setState(() {
        _composer.clear();
        _attachments.clear();
      });
    }
    if (accepted &&
        mounted &&
        _replyNotifications &&
        _lifecycle != AppLifecycleState.resumed) {
      final failed =
          _chat!.active?.messages.lastOrNull?.state ==
          AiChatMessageState.failed;
      unawaited(AiChatNotifications.showReplyReady(failed: failed));
    }
  }

  Future<void> _showDiagnostics(AiChatMessage message) async {
    await showDialog<void>(
      context: context,
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
            builder: (_) => _AiEditMessageDialog(message: original),
          )
        : original;
    if (message == null) return;
    await _send(edited: message, retryUserIndex: user);
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
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
      if (mounted) setState(() => _syncing = false);
    }
  }

  Widget _history({bool drawer = false}) {
    final chat = _chat!;
    final folders = {
      ...chat.conversations.map((c) => c.folder).where((f) => f.isNotEmpty),
      if (chat.folder != null) chat.folder!,
    }.toList()..sort();
    return Column(
      children: [
        ListTile(
          title: const Text('Conversations'),
          trailing: IconButton(
            tooltip: 'New chat',
            onPressed: chat.busy
                ? null
                : () {
                    chat.newChat();
                    _composer.clear();
                    _attachments.clear();
                    if (drawer) Navigator.pop(context);
                  },
            icon: const Icon(Icons.add),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search chats and messages',
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
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String>(
            key: ValueKey(chat.folder),
            initialValue: chat.folder ?? '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Folder'),
            items: [
              const DropdownMenuItem(value: '', child: Text('All folders')),
              ...folders.map((f) => DropdownMenuItem(value: f, child: Text(f))),
            ],
            onChanged: chat.busy
                ? null
                : (v) {
                    chat.folder = v == '' ? null : v;
                    unawaited(chat.refresh());
                  },
          ),
        ),
        SwitchListTile(
          title: const Text('Archived'),
          value: chat.showArchived,
          onChanged: chat.busy
              ? null
              : (v) {
                  chat.showArchived = v;
                  unawaited(chat.refresh());
                },
        ),
        Expanded(
          child: ListView(
            children: [
              if (chat.conversations.isEmpty)
                const ListTile(title: Text('No conversations found')),
              ...chat.conversations.map(
                (c) => ListTile(
                  selected: c.id == chat.active?.id,
                  leading: Icon(
                    c.pinned ? Icons.push_pin : Icons.chat_bubble_outline,
                  ),
                  title: Text(
                    c.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: c.folder.isEmpty ? null : Text(c.folder),
                  onTap: chat.busy
                      ? null
                      : () async {
                          await _select(c);
                          if (drawer && mounted) Navigator.pop(context);
                        },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _message(AiChatMessage m, int index) {
    final assistant = m.message.role == AiRole.assistant;
    final last = index == _chat!.active!.messages.length - 1;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: assistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 860),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: assistant
              ? scheme.surfaceContainerLow
              : scheme.primaryContainer,
          border: Border.all(
            color: assistant
                ? scheme.outlineVariant.withValues(alpha: .55)
                : scheme.primary.withValues(alpha: .12),
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(assistant ? 6 : 20),
            bottomRight: Radius.circular(assistant ? 20 : 6),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: .035),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              assistant
                  ? 'DayArk${m.model == null ? '' : ' · ${m.model}'}'
                  : 'You',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            if (last && _chat!.thinkingText.isNotEmpty)
              Material(
                key: ValueKey('thinking-${m.id}'),
                color: Colors.transparent,
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    _chat!.activity == 'Thinking…'
                        ? 'Thinking…'
                        : 'Model thinking',
                  ),
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: SingleChildScrollView(
                        child: SelectableText(_chat!.thinkingText),
                      ),
                    ),
                  ],
                ),
              ),
            if (m.state == AiChatMessageState.pending && m.message.text == '…')
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
                    child: Text(_chat!.activity ?? 'Waiting for model…'),
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
                      m.error ?? 'The provider could not complete this reply.',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showDiagnostics(m),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('View thinking and response'),
                    ),
                  ],
                ),
              )
            else if (m.state == AiChatMessageState.pending)
              SelectableText(m.message.text)
            else
              MarkdownBody(
                data: m.message.text,
                selectable: true,
                // Model-generated remote images must never trigger hidden network requests.
                imageBuilder: (uri, title, alt) =>
                    Text('[Image: ${alt ?? title ?? uri.toString()}]'),
                onTapLink: (text, href, title) async {
                  final uri = Uri.tryParse(href ?? '');
                  if (uri != null &&
                      ['https', 'http'].contains(uri.scheme) &&
                      uri.userInfo.isEmpty) {
                    final yes = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Open external link?'),
                        content: Text(uri.toString()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
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
                      launchUrl(uri, mode: LaunchMode.externalApplication);
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
            if (m.state != AiChatMessageState.complete &&
                m.state != AiChatMessageState.failed)
              Text(
                m.state.name,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (m.error != null &&
                m.state != AiChatMessageState.failed &&
                m.message.text != m.error)
              Text(m.error!),
            Wrap(
              spacing: 8,
              children: [
                IconButton(
                  tooltip: 'Copy message',
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: m.message.text)),
                  icon: const Icon(Icons.copy, size: 18),
                ),
                if (!assistant)
                  TextButton(
                    onPressed: _chat!.busy
                        ? null
                        : () => _retry(index, edit: true),
                    child: const Text('Edit'),
                  ),
                if (assistant && last)
                  TextButton(
                    onPressed: _chat!.busy ? null : () => _retry(index),
                    child: Text(
                      m.state == AiChatMessageState.complete
                          ? 'Regenerate'
                          : 'Retry',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    if (chat == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Chat')),
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
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    final compact = availableHeight < 420;
    final c = chat.active;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          c?.title ?? 'AI Chat',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'AI settings',
            onPressed: chat.busy ? null : _settingsPage,
            icon: const Icon(Icons.settings_outlined),
          ),
          if (c != null)
            PopupMenuButton<String>(
              enabled: !chat.busy && !_syncing,
              onSelected: _action,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(
                  value: 'pin',
                  child: Text(c.pinned ? 'Unpin' : 'Pin'),
                ),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(c.archived ? 'Unarchive' : 'Archive'),
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
                const PopupMenuItem(value: 'txt', child: Text('Export text')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      drawer: wide
          ? null
          : Drawer(child: SafeArea(child: _history(drawer: true))),
      body: Row(
        children: [
          if (wide)
            SizedBox(
              width: 304,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: _history(),
                ),
              ),
            ),
          Expanded(
            child: Column(
              children: [
                if (!keyboard || availableHeight >= 300)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(_profileId),
                            initialValue: _profile?.id,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'AI profile',
                              border: OutlineInputBorder(),
                            ),
                            items: _preferences.profiles
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p.id,
                                    child: Text(
                                      '${p.name} · ${p.modelId}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: chat.busy
                                ? null
                                : (id) {
                                    setState(() => _profileId = id);
                                    unawaited(chat.update(profileId: id));
                                  },
                          ),
                        ),
                        if (_profile?.kind == AiProviderKind.ollama ||
                            _profile?.kind == AiProviderKind.offline)
                          Tooltip(
                            triggerMode: TooltipTriggerMode.tap,
                            message:
                                'Local model speed depends on the system running it. '
                                'Loading, thinking and responding can take several minutes. '
                                'DayArk waits until it finishes or you press Stop. '
                                'For faster responses, choose a lighter model; answer quality may be lower.',
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(Icons.info_outline),
                            ),
                          ),
                        IconButton(
                          tooltip: 'New chat',
                          onPressed: chat.busy
                              ? null
                              : () {
                                  chat.newChat();
                                  _composer.clear();
                                  setState(_attachments.clear);
                                },
                          icon: const Icon(Icons.add_comment_outlined),
                        ),
                      ],
                    ),
                  ),
                if (_profile != null && !compact)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _profile!.kind == AiProviderKind.offline
                          ? 'On-device processing'
                          : 'Sending shares this conversation and its attachments with ${_profile!.kind.name}. Online permission is controlled in AI settings.',
                    ),
                  ),
                if (chat.status != null && !compact)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      chat.status!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Expanded(
                  child: c == null
                      ? Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 560),
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withValues(alpha: .65),
                                    Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerLow,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 32,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    foregroundColor: Theme.of(context)
                                        .colorScheme
                                        .onPrimary,
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'How can DayArk help?',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Start a private conversation, attach a document, or switch models at any time.',
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_preferences.profiles.isEmpty)
                                    FilledButton(
                                      onPressed: _settingsPage,
                                      child: const Text('Set up AI'),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          itemCount: c.messages.length,
                          itemBuilder: (_, i) => _message(c.messages[i], i),
                        ),
                ),
                if (_attachments.isNotEmpty)
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _attachments
                          .map(
                            (a) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: InputChip(
                                label: Text(a.name ?? 'Attachment'),
                                onDeleted: chat.busy
                                    ? null
                                    : () => setState(
                                        () => _attachments.remove(a),
                                      ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Attach files',
                          onPressed: chat.busy ? null : _pick,
                          icon: const Icon(Icons.attach_file),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _composer,
                            enabled: !chat.busy && !_syncing,
                            minLines: 1,
                            maxLines: compact ? 2 : 6,
                            decoration: const InputDecoration(
                              hintText: 'Message DayArk…',
                              border: InputBorder.none,
                            ),
                            textInputAction: TextInputAction.newline,
                          ),
                        ),
                        IconButton.filled(
                          tooltip: chat.busy ? 'Stop response' : 'Send message',
                          onPressed: _syncing
                              ? null
                              : chat.busy
                              ? chat.stop
                              : () => _send(),
                          icon: Icon(chat.busy ? Icons.stop : Icons.send),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!keyboard)
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 330,
                        child: SwitchListTile.adaptive(
                          dense: true,
                          title: const Text('Automatic paired-device sync'),
                          subtitle: const Text(
                            'Uses the existing local sync cycle',
                          ),
                          value: _syncEnabled,
                          onChanged: chat.busy || _syncing
                              ? null
                              : (v) async {
                                  await chat.store.setSyncEnabled(v);
                                  if (mounted) setState(() => _syncEnabled = v);
                                },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sync shared chats now',
                        onPressed: !_syncEnabled || chat.busy || _syncing
                            ? null
                            : _sync,
                        icon: _syncing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync),
                      ),
                      SizedBox(
                        width: 300,
                        child: SwitchListTile.adaptive(
                          dense: true,
                          title: const Text('Reply-ready notifications'),
                          value: _replyNotifications,
                          onChanged: (v) async {
                            await chat.store.setReplyNotificationsEnabled(v);
                            if (mounted) {
                              setState(() => _replyNotifications = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                if (_syncEnabled && !keyboard)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      'When enabled, all AI conversations sync automatically with paired devices.',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _chat?.removeListener(_changed);
    _chat?.dispose();
    _composer.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }
}

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
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.note != null) Text(widget.note!),
        TextField(
          controller: _input,
          autofocus: true,
          maxLines: widget.title == 'Edit message' ? 6 : 1,
          maxLength: widget.title == 'Rename conversation'
              ? 200
              : widget.title == 'Move to folder'
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
