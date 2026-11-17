import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../services/device_sync/device_sync_service.dart';
import '../../screens/navigation/widgets/desktop_navigation_scope.dart';
import '../../utlis/app_router.dart';
import '../core/ai_attachments.dart';
import '../core/ai_capabilities.dart';
import '../core/ai_cancellation.dart';
import '../core/ai_error.dart';
import '../core/ai_input_preparation.dart';
import '../providers/http/http_ai_provider.dart';
import '../settings/ai_settings.dart';
import 'ai_input_reduction.dart';
import '../widgets/ai_choice_picker.dart';
import '../widgets/ai_response_text.dart';
import '../voice/voice_input_dialog.dart';
import '../memory/memory_store.dart';
import '../memory/memory_screen.dart';
import '../memory/memory_context_service.dart';
import '../models/ai_models.dart';
import '../settings/ai_preferences.dart';
import '../settings/ai_defaults_screen.dart' show aiProviderLabel;
import '../settings/ai_configured_assistant.dart';
import '../settings/ai_settings_screen.dart';
import '../settings/ai_settings_store.dart';
import 'ai_chat_controller.dart';
import 'ai_chat_notifications.dart';
import 'ai_chat_store.dart';
import 'ai_conversation.dart';

enum _HistoryAction { pin, move }

/// A nested navigator confines chat dialogs to the chat pane on desktop.
class AiChatScreen extends StatefulWidget {
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
  State<AiChatScreen> createState() => _AiChatHostState();
}

class _AiChatHostState extends State<AiChatScreen> {
  final _navigator = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) => ClipRect(
    child: NavigatorPopHandler<void>(
      onPopWithResult: (_) => _navigator.currentState!.pop(),
      child: Navigator(
        key: _navigator,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => _AiChatPane(
            store: widget.store,
            settings: widget.settings,
            engine: widget.engine,
            sync: widget.sync,
          ),
        ),
      ),
    ),
  );
}

class _AiChatPane extends ConsumerStatefulWidget {
  const _AiChatPane({this.store, this.settings, this.engine, this.sync});
  final AiChatStore? store;
  final AiSettingsStore? settings;
  final AiChatStream? engine;
  final Future<String> Function()? sync;
  @override
  ConsumerState<_AiChatPane> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<_AiChatPane>
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
  bool _framePending = false, _preparing = false, _draftPrivate = false;
  AiCancellationToken? _preparationToken;
  int? _draftRetryIndex;
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
      final memory = widget.engine == null ? await sharedMemoryManager() : null;
      if (!mounted) return;
      final assistant = AiConfiguredAssistant(
        settings,
        memory: memory == null
            ? null
            : MemoryContextService(memory, chats: store),
      );
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
    if (_framePending) return;
    _framePending = true;
    final follow = !_scroll.hasClients || _scroll.offset < 160;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _framePending = false;
      if (!mounted) return;
      setState(() {});
      if (follow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.jumpTo(0);
          }
        });
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
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

  Future<void> _chooseProfile() async {
    if (_preferences.profiles.isEmpty) {
      await _settingsPage();
      return;
    }
    final id = await showAiChoicePicker(
      context,
      title: 'Choose a model',
      selected: _profileId,
      choices: [
        for (final p in _preferences.profiles)
          AiChoice(
            p.id,
            '${p.name} · ${p.modelId}',
            subtitle: p.kind == AiProviderKind.offline
                ? 'On device'
                : aiProviderLabel(p.kind),
            icon: p.kind == AiProviderKind.offline
                ? Icons.computer_outlined
                : Icons.cloud_outlined,
          ),
      ],
    );
    if (!mounted || id == null || _chat!.busy) return;
    setState(() => _profileId = id);
    await _chat!.update(profileId: id);
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
                setState(() => _syncEnabled = value);
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
                setState(() => _replyNotifications = value);
                update(() {});
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );

  Future<void> _select(AiConversation c) async {
    if (_preparing) return;
    await _chat!.select(c.id);
    if (!mounted) return;
    setState(() {
      _profileId =
          _preferences.profiles.any((p) => p.id == _chat!.active?.profileId)
          ? _chat!.active!.profileId
          : _preferences.selectedProfileId;
      _attachments.clear();
      _composer.clear();
      _draftPrivate = false;
      _draftRetryIndex = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  Future<String?> _editText(
    String title,
    String initial, {
    String action = 'Save',
    String? note,
  }) => showDialog<String>(
    context: context,
    useRootNavigator: false,
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
          final name = await _chooseFolder(c!.folder);
          if (name != null) await chat.update(folder: name);
        case 'pin':
          await chat.update(pinned: !c!.pinned);
        case 'archive':
          await chat.update(archived: !c!.archived);
        case 'delete':
          final yes = await showDialog<bool>(
            context: context,
            useRootNavigator: false,
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

  Future<void> _pick({bool images = false}) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: images
            ? ['png', 'jpg', 'jpeg', 'webp']
            : ['pdf', 'txt', 'md'],
      );
      if (result.isEmpty || !mounted) return;
      if (_attachments.length + result.length > 8) {
        throw const FormatException(
          'You can attach up to 8 files. Please remove some files.',
        );
      }
      final picked = <AiAttachment>[];
      for (final file in result) {
        if (await file.length() > aiMaxAttachmentBytes) {
          throw const FormatException(
            'This file exceeds the 8 MiB limit. Please use a smaller file.',
          );
        }
        final buffer = BytesBuilder(copy: false);
        await for (final chunk in file.readAsByteStream()) {
          if (buffer.length + chunk.length > aiMaxAttachmentBytes) {
            throw const FormatException(
              'This file exceeds the 8 MiB limit. Please use a smaller file.',
            );
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
        throw const FormatException(
          'The selected files exceed 16 MiB together. Please use fewer or smaller files.',
        );
      }
      if (mounted) setState(() => _attachments.addAll(picked));
    } on AiException catch (error) {
      _notice(error.message);
    } on FormatException catch (error) {
      _notice(error.message);
    } catch (_) {
      _notice(
        'Unable to read this file. Try a readable PNG, JPEG, WebP, PDF, UTF-8 TXT or Markdown file.',
      );
    }
  }

  String? _capabilitiesKey;
  AiCapabilities? _capabilities;
  AiCapabilities _inputCapabilities() {
    final key = '${_profile!.kind}:${_profile!.modelId}';
    if (_capabilitiesKey == key && _capabilities != null) return _capabilities!;
    _capabilitiesKey = key;
    if (_profile!.kind == AiProviderKind.offline) {
      return _capabilities = AiCapabilities(contextWindow: true);
    }
    final provider = _profile!.createProvider(credentials: () async => null);
    try {
      return _capabilities = provider.capabilitiesFor(_profile!.modelId);
    } finally {
      if (provider is HttpAiProvider) provider.close();
    }
  }

  Future<void> _summarizeInput(
    AiMessage prepared,
    AiSettings settings,
    int budget,
    int? retryIndex,
  ) async {
    final progress = ValueNotifier('Preparing text…');
    final thoughts = ValueNotifier('');
    var thoughtBuffer = StringBuffer();
    Timer? thoughtRefresh;
    final token = AiCancellationToken();
    _preparationToken = token;
    final summarySettings = AiSettings.fromJson({
      ...settings.toJson(),
      'maxOutputTokens': 128,
      'thinking': false,
    });
    final engine =
        widget.engine ??
        ({
          required message,
          required history,
          required profileId,
          required cancellationToken,
        }) => AiConfiguredAssistant(_settings!).stream(
          message: message,
          history: history,
          profileId: profileId,
          cancellationToken: cancellationToken,
          settingsOverride: summarySettings,
        );
    final dialog = showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 400),
          scrollable: true,
          title: const Text('Summarizing input'),
          content: ValueListenableBuilder<String>(
            valueListenable: progress,
            builder: (_, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
                Text(value),
                ValueListenableBuilder<String>(
                  valueListenable: thoughts,
                  builder: (_, text, _) => text.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            height: 120,
                            width: 360,
                            child: SingleChildScrollView(
                              child: AiResponseText(
                                data: text,
                                live: true,
                                maxHeight: 120,
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
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: token.cancel, child: const Text('Cancel')),
          ],
        ),
      ),
    );
    AiMessage? reduced;
    String? errorMessage;
    try {
      reduced = await const AiInputReduction().summarize(
        prepared: prepared,
        budget: budget,
        partBudget: aiInputBudget(summarySettings),
        profileId: _profileId!,
        engine: engine,
        cancellationToken: token,
        onProgress: (part, total, pass) {
          progress.value = 'Pass $pass · part $part of $total';
          thoughtRefresh?.cancel();
          thoughtRefresh = null;
          thoughtBuffer = StringBuffer();
          thoughts.value = '';
        },
        onThinking: (delta) {
          thoughtBuffer.write(delta);
          thoughtRefresh ??= Timer(const Duration(milliseconds: 100), () {
            thoughtRefresh = null;
            thoughts.value = thoughtBuffer.toString();
          });
        },
      );
    } on AiException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage =
          'Unable to summarize the input. Please try a smaller file.';
    } finally {
      _preparationToken = null;
      if (mounted) {
        Navigator.of(context).pop();
        await dialog;
      }
      thoughtRefresh?.cancel();
      progress.dispose();
      thoughts.dispose();
    }
    if (!mounted) return;
    if (token.isCancelled) {
      _notice('Summarization cancelled. Your original draft is unchanged.');
      return;
    }
    if (reduced == null) {
      _notice(errorMessage!);
      return;
    }
    final prompt = await _editText(
      'Review shortened prompt',
      reduced.text,
      action: 'Use summary',
      note: 'I don’t recommend summarizing with this AI tool because it might miss important information. Review and edit the shortened prompt before sending.',
    );
    if (!mounted || prompt == null) return;
    try {
      checkAiInputBudget(AiMessage(role: AiRole.user, text: prompt), settings);
    } on AiException catch (error) {
      _notice(error.message);
      return;
    }
    setState(() {
      _composer.text = prompt;
      _attachments.clear();
      _draftPrivate = reduced!.containsPrivateContext;
      _draftRetryIndex = retryIndex;
    });
  }

  Future<void> _send({AiMessage? edited, int? retryUserIndex}) async {
    if (_chat!.busy ||
        _preparing ||
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
          containsPrivateContext: _draftPrivate,
        );
    if (_profile == null) {
      _notice('Create a provider profile in AI settings first.');
      return;
    }
    final retryIndex = retryUserIndex ?? _draftRetryIndex;
    AiMessage? prepared;
    final settings = _settings!.load().settings;
    setState(() => _preparing = true);
    try {
      prepared = await prepareAiInput(message, _inputCapabilities());
      checkAiInputBudget(prepared, settings);
    } on AiInputTooLarge catch (error) {
      if (!mounted) return;
      final canSummarize =
          prepared != null &&
          prepared.attachments.isEmpty &&
          error.budget >= 256;
      final summarize = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        builder: (context) => AlertDialog(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
          scrollable: true,
          title: const Text('Input exceeds the model limit'),
          content: Text(
            '${_profile!.modelId}: ${error.message}\n\nI don’t recommend summarizing with this AI tool because it might miss important information.\n\n'
            '${canSummarize ? 'Summarize the input in parts with this same model? Each part is sent to ${_profile!.name}. This can take several requests. You can cancel and review the final prompt before sending.' : 'Choose a smaller input or increase the context window in AI settings.'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep draft'),
            ),
            if (canSummarize)
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Summarize in parts'),
              ),
          ],
        ),
      );
      if (summarize == true && mounted) {
        await _summarizeInput(prepared!, settings, error.budget, retryIndex);
      }
      return;
    } on AiException catch (error) {
      _notice(error.message);
      return;
    } on FormatException catch (error) {
      _notice(error.message);
      return;
    } catch (_) {
      _notice(
        'Unable to prepare this input. Please try a smaller readable file.',
      );
      return;
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
    if (!mounted) return;
    final accepted = await _chat!.send(
      message,
      profileId: _profileId,
      provider: _profile!.kind.name,
      model: _profile!.modelId,
      retryUserIndex: retryIndex,
      onAccepted: () {
        if (edited == null && mounted) {
          setState(() {
            _composer.clear();
            _attachments.clear();
            _draftPrivate = false;
            _draftRetryIndex = null;
          });
        }
      },
    );
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

  Widget _history({bool drawer = false}) {
    final chat = _chat!;
    return Column(
      children: [
        ListTile(
          title: const Text('Conversations'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'New folder',
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: chat.busy || _preparing
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
                icon: const Icon(Icons.edit_square),
                onPressed: chat.busy || _preparing
                    ? null
                    : () {
                        chat.newChat();
                        _composer.clear();
                        _attachments.clear();
                        _draftPrivate = false;
                        if (drawer) Navigator.pop(context);
                      },
              ),
            ],
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
              ListTile(
                title: const Text('All chats'),
                leading: const Icon(Icons.forum_outlined),
                selected: chat.folder == null,
                onTap: chat.busy || _preparing
                    ? null
                    : () {
                        chat.folder = null;
                        unawaited(chat.refresh());
                      },
              ),
              for (final folder in chat.folders)
                ListTile(
                  title: Text(
                    folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  leading: const Icon(Icons.folder_outlined),
                  selected: chat.folder == folder.name,
                  trailing: IconButton(
                    tooltip: folder.pinned ? 'Unpin folder' : 'Pin folder',
                    icon: Icon(
                      folder.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 18,
                    ),
                    onPressed: chat.busy || _preparing
                        ? null
                        : () async {
                            await chat.store.saveFolder(
                              folder.name,
                              pinned: !folder.pinned,
                            );
                            await chat.refresh();
                          },
                  ),
                  onTap: chat.busy || _preparing
                      ? null
                      : () {
                          chat.folder = folder.name;
                          unawaited(chat.refresh());
                        },
                ),
              const Divider(indent: 16, endIndent: 16),

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
            ],
          ),
        ),
      ],
    );
  }

  String _elapsed(int milliseconds) {
    final seconds = milliseconds / 1000;
    return seconds < 60
        ? '${seconds.toStringAsFixed(1)}s'
        : '${seconds ~/ 60}m ${(seconds % 60).toStringAsFixed(0)}s';
  }

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
    final inputCapabilities = _profile == null ? null : _inputCapabilities();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        scrolledUnderElevation: 0,
        title: TextButton(
          onPressed: (chat.busy || _preparing) ? null : _chooseProfile,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _profile?.modelId ?? 'DayArk AI',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Chat preferences',
            onPressed: (chat.busy || _preparing) || _syncing
                ? null
                : _chatPreferences,
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: 'Memory & knowledge',
            onPressed: (chat.busy || _preparing)
                ? null
                : () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => const MemoryScreen()),
                  ),
            icon: const Icon(Icons.psychology_outlined),
          ),
          IconButton(
            tooltip: 'AI settings',
            onPressed: (chat.busy || _preparing) ? null : _settingsPage,
            icon: const Icon(Icons.settings_outlined),
          ),
          if (c != null)
            PopupMenuButton<String>(
              enabled: !(chat.busy || _preparing) && !_syncing,
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
                if (!compact)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _profile?.kind == AiProviderKind.offline
                              ? Icons.lock_outline
                              : Icons.cloud_outlined,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _profile == null
                                ? 'Choose a model to start'
                                : _profile!.kind == AiProviderKind.offline
                                ? 'On-device processing'
                                : 'Messages are sent to ${_profile!.name}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (_profile?.kind == AiProviderKind.ollama ||
                            _profile?.kind == AiProviderKind.offline)
                          const Tooltip(
                            triggerMode: TooltipTriggerMode.tap,
                            message:
                                'Local model speed depends on the system running it. '
                                'For faster responses, choose a lighter model; answer quality may be lower.',
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.info_outline, size: 18),
                            ),
                          ),
                        IconButton(
                          tooltip: 'New chat',
                          onPressed: (chat.busy || _preparing)
                              ? null
                              : () {
                                  chat.newChat();
                                  _composer.clear();
                                  setState(() {
                                    _attachments.clear();
                                    _draftPrivate = false;
                                    _draftRetryIndex = null;
                                  });
                                },
                          icon: const Icon(Icons.edit_square, size: 20),
                        ),
                      ],
                    ),
                  ),
                if (chat.status != null &&
                    chat.status != c?.messages.lastOrNull?.error &&
                    !compact)
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
                                  const SizedBox(height: 12),
                                  const Text(
                                    'A little clarity for your day.',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  if (_preferences.profiles.isNotEmpty)
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        for (final prompt in [
                                          'Explain something',
                                          'Help me write',
                                          'Brainstorm ideas',
                                        ])
                                          ActionChip(
                                            label: Text(prompt),
                                            onPressed: () {
                                              _composer.text = '$prompt: ';
                                            },
                                          ),
                                      ],
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
                          reverse: true,
                          findChildIndexCallback: (key) {
                            if (key is! ValueKey<String>) return null;
                            final index = c.messages.indexWhere(
                              (message) => message.id == key.value,
                            );
                            return index < 0
                                ? null
                                : c.messages.length - 1 - index;
                          },
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: c.messages.length,
                          itemBuilder: (_, i) {
                            final index = c.messages.length - 1 - i;
                            return Center(
                              key: ValueKey(c.messages[index].id),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 800,
                                ),
                                child: _message(c.messages[index], index),
                              ),
                            );
                          },
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
                                onDeleted: (chat.busy || _preparing)
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
                if (_attachments.isNotEmpty && !compact)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: Text(
                      'TXT/Markdown become text. PDFs are extracted locally for text-only models. Images require configured vision support. Voice becomes editable text. All converted text counts toward the context limit.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerLow,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: TextField(
                                controller: _composer,
                                enabled: !_syncing && !_preparing,
                                minLines: 1,
                                maxLines: compact ? 2 : 6,
                                decoration: const InputDecoration(
                                  hintText: 'Message DayArk…',
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                ),
                                textInputAction: TextInputAction.newline,
                              ),
                            ),
                            Row(
                              children: [
                                if (inputCapabilities != null)
                                  IconButton(
                                    tooltip: 'Attach files',
                                    onPressed: chat.busy || _preparing
                                        ? null
                                        : () => _pick(),
                                    icon: const Icon(Icons.add_rounded),
                                  ),
                                if (inputCapabilities?.attachments.contains(
                                      AiAttachmentKind.image,
                                    ) ==
                                    true)
                                  IconButton(
                                    tooltip: 'Attach images',
                                    onPressed: chat.busy || _preparing
                                        ? null
                                        : () => _pick(images: true),
                                    icon: const Icon(Icons.image_outlined),
                                  ),
                                if (_profile != null)
                                  IconButton(
                                    tooltip: 'Voice input',
                                    onPressed:
                                        (chat.busy || _preparing) || _syncing
                                        ? null
                                        : () async {
                                            final transcript =
                                                await showDialog<String>(
                                                  context: context,
                                                  useRootNavigator: false,
                                                  barrierDismissible: false,
                                                  builder: (_) =>
                                                      VoiceInputDialog(
                                                        settings: _settings!,
                                                      ),
                                                );
                                            if (!mounted ||
                                                transcript == null) {
                                              return;
                                            }
                                            _composer.text =
                                                [_composer.text, transcript]
                                                    .where((s) => s.isNotEmpty)
                                                    .join('\n');
                                          },
                                    icon: const Icon(Icons.mic_none),
                                  ),
                                const Spacer(),
                                IconButton.filled(
                                  tooltip: (chat.busy || _preparing)
                                      ? 'Stop response'
                                      : 'Send message',
                                  onPressed: _syncing
                                      ? null
                                      : (chat.busy || _preparing)
                                      ? (_preparing
                                            ? () => _preparationToken?.cancel()
                                            : chat.stop)
                                      : () => _send(),
                                  icon: Icon(
                                    (chat.busy || _preparing)
                                        ? Icons.stop_rounded
                                        : Icons.arrow_upward_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (!keyboard && !compact)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'AI can make mistakes. Check important information.',
                      style: Theme.of(context).textTheme.bodySmall,
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
    _preparationToken?.cancel();
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
              widget.title == 'Edit message' ||
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
