import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../services/device_sync/device_sync_service.dart';
import '../../utlis/app_router.dart';
import '../core/ai_attachments.dart';
import '../core/ai_capabilities.dart';
import '../core/ai_cancellation.dart';
import '../core/ai_error.dart';
import '../core/ai_stream.dart';
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
import '../prompts/prompt_manager.dart';
import '../settings/ai_preferences.dart';
import '../settings/ai_defaults_screen.dart' show aiProviderLabel;
import '../settings/ai_configured_assistant.dart';
import '../settings/ai_settings_screen.dart';
import '../settings/ai_settings_store.dart';
import 'ai_chat_controller.dart';
import 'ai_chat_notifications.dart';
import 'ai_chat_store.dart';
import 'ai_conversation.dart';
import 'ai_workspace_store.dart';
import '../settings/ai_local_models_factory.dart';
import '../settings/ai_local_models.dart';
import '../settings/ai_local_models_page.dart';
import '../performance/performance_profile.dart';
import 'widgets/ai_workspace_inspector.dart';
import 'widgets/ai_chat_welcome.dart';

part 'ai_chat_workspace.dart';
part 'ai_chat_dialogs.dart';
part 'ai_chat_management.dart';
part 'ai_chat_preparation.dart';
part 'ai_chat_actions.dart';
part 'ai_chat_preferences.dart';
part 'ai_chat_composer.dart';
part 'ai_chat_history.dart';
part 'ai_chat_message.dart';
part 'ai_chat_library.dart';

enum _HistoryAction { pin, move }

/// A nested navigator confines chat dialogs to the chat pane on desktop.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({
    super.key,
    this.store,
    this.settings,
    this.engine,
    this.sync,
    this.localModels,
    this.memory,
  });
  final AiChatStore? store;
  final AiSettingsStore? settings;
  final AiChatStream? engine;
  final Future<String> Function()? sync;
  final Future<AiLocalModels> Function()? localModels;
  final Future<MemoryManager> Function()? memory;
  @override
  State<AiChatScreen> createState() => _AiChatHostState();
}

class _AiChatHostState extends State<AiChatScreen> {
  final _navigator = GlobalKey<NavigatorState>();
  void _back() {
    // This context belongs to the application route, outside the pane navigator.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      GoRouter.maybeOf(context)?.go(RoutesStr.home);
    }
  }

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
            localModels: widget.localModels,
            memory: widget.memory,
            onBack: _back,
          ),
        ),
      ),
    ),
  );
}

class _AiChatPane extends ConsumerStatefulWidget {
  const _AiChatPane({
    this.store,
    this.settings,
    this.engine,
    this.sync,
    this.localModels,
    this.memory,
    required this.onBack,
  });
  final AiChatStore? store;
  final AiSettingsStore? settings;
  final AiChatStream? engine;
  final Future<String> Function()? sync;
  final Future<AiLocalModels> Function()? localModels;
  final Future<MemoryManager> Function()? memory;
  final VoidCallback onBack;
  @override
  ConsumerState<_AiChatPane> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<_AiChatPane>
    with WidgetsBindingObserver {
  AiChatController? _chat;
  AiWorkspaceStore? _workspace;
  AiSettings? _nextResponseSettings;
  String _nextResponseInstructions = '';
  AiCapabilities Function(String)? _offlineCapabilities;
  Future<MemoryManager>? _memoryFuture;
  Future<AiLocalModels>? _modelsFuture;
  Future<AiLocalModels> _getLocalModels() =>
      _modelsFuture ??= (widget.localModels ?? sharedAiLocalModels)()
          .then((models) {
            if (mounted) {
              _loadedLocalModels = models;
              _offlineCapabilities = models.provider?.capabilitiesFor;
              _capabilitiesKey = null;
            }
            return models;
          })
          .catchError((Object error) {
            _modelsFuture = null;
            throw error;
          });
  AiLocalModels? _loadedLocalModels;

  Future<T> _awaitResource<T>(
    Future<T> resource,
    AiCancellationToken token,
  ) async {
    token.throwIfCancelled();
    final cancelled = Completer<T>();
    final remove = token.onCancel(
      () => cancelled.completeError(
        const AiException(AiErrorCode.cancelled, 'AI request cancelled.'),
      ),
    );
    try {
      return await Future.any([resource, cancelled.future]);
    } finally {
      remove();
    }
  }

  Stream<AiStreamEvent> _configuredStream({
    required AiSettingsStore settings,
    required AiChatStore store,
    required AiMessage message,
    required Iterable<AiMessage> history,
    required String? profileId,
    required AiCancellationToken cancellationToken,
  }) async* {
    final preferences = settings.load();
    final profile = preferences.profiles
        .where((p) => p.id == profileId)
        .firstOrNull;
    AiLocalModels? local;
    if (profile?.kind == AiProviderKind.offline) {
      yield const AiStreamEvent.activity(diagnostic: 'Loading model…');
      final ready = await _awaitResource<AiLocalModels>(
        _getLocalModels(),
        cancellationToken,
      );
      local = ready;
      _loadedLocalModels = ready;
      _offlineCapabilities = ready.provider?.capabilitiesFor;
      _capabilitiesKey = null;
      if (ready.busy) {
        throw const AiException(
          AiErrorCode.providerUnavailable,
          'Local model maintenance is in progress.',
        );
      }
    }
    final memory = preferences.settings.useMemory
        ? await _awaitResource<MemoryManager>(
            _memoryFuture ??= (widget.memory ?? sharedMemoryManager)()
                .catchError((Object error) {
                  _memoryFuture = null;
                  throw error;
                }),
            cancellationToken,
          )
        : null;
    cancellationToken.throwIfCancelled();
    final assistant = AiConfiguredAssistant(
      settings,
      memory: memory == null
          ? null
          : MemoryContextService(memory, chats: store),
    );
    yield* assistant.stream(
      settingsOverride: _takeNextSettings(),
      offline: local?.provider,
      message: message,
      history: history,
      profileId: profileId,
      cancellationToken: cancellationToken,
      onPreparedMessages: (messages) {
        if (!mounted) return;
        setState(() {
          _lastPrompt = messages;
          _lastPromptChatId = _chat?.active?.id;
        });
      },
    );
  }

  AiSettings _takeNextSettings() {
    final value = _responseSettings();
    _nextResponseSettings = null;
    _nextResponseInstructions = '';
    return value;
  }

  AiSettings _responseSettings() {
    final settings = _nextResponseSettings ?? _settings!.load().settings;
    final instructions = [
      settings.customInstructions,
      if (_chat?.active?.instructions.isNotEmpty ?? false)
        'Conversation preferences (override global preferences):\n${_chat!.active!.instructions}',
      if (_nextResponseInstructions.isNotEmpty)
        'For this response (override other user preferences):\n$_nextResponseInstructions',
    ].where((s) => s.isNotEmpty).join('\n\n');
    return AiSettings.fromJson({
      ...settings.toJson(),
      'customInstructions': instructions,
    });
  }

  bool _sidebarCollapsed = false, _inspector = true, _favouritesOnly = false;
  double _sidebarWidth = 240;
  final _composerFocus = FocusNode(), _searchFocus = FocusNode();
  Timer? _draftTimer;
  // Cached completed message widgets are retained by identity across stream updates.
  Object? _messageTheme;
  bool? _messageBusy;
  String? _messageChatId;
  int? _messageCount;
  final _messageWidgets = <String, (AiChatMessage, Widget)>{};

  void _update(VoidCallback action) => setState(action);
  void _newChat() {
    if (_chat!.busy || _preparing) return;
    _saveDraft();
    _chat!.newChat();
    _composer.text = _workspace?.draft(null) ?? '';
    _update(() {
      _attachments.clear();
      _draftPrivate = false;
      _draftRetryIndex = null;
    });
  }

  void _saveDraft() {
    final workspace = _workspace;
    if (workspace != null) {
      unawaited(workspace.saveDraft(_chat?.active?.id, _composer.text));
    }
  }

  void _draftChanged() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), _saveDraft);
  }

  void _toggleSidebar() {
    _update(() => _sidebarCollapsed = !_sidebarCollapsed);
    unawaited(_workspace!.layout(collapsed: _sidebarCollapsed));
  }

  void _toggleInspector() {
    _update(() => _inspector = !_inspector);
    unawaited(_workspace!.layout(inspector: _inspector));
  }

  Future<void> _performance(AiPerformanceProfile profile) async {
    if (_chat!.busy || _preparing) return;
    final mobile =
        Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;
    final current = _settings!.load();
    final settings = profile == AiPerformanceProfile.custom
        ? AiSettings.fromJson({
            ...current.settings.toJson(),
            'performanceProfile': 'custom',
          })
        : profile.apply(current.settings, mobile: mobile);
    final value = AiPreferences(
      profiles: current.profiles,
      selectedProfileId: current.selectedProfileId,
      settings: settings,
      allowOnlineProcessing: current.allowOnlineProcessing,
      allowPrivateContextOnline: current.allowPrivateContextOnline,
    );
    try {
      await _settings!.save(value);
      if (mounted) _update(() => _preferences = value);
    } catch (_) {
      if (mounted) _notice('Unable to save performance preferences.');
    }
  }

  Future<void> _continue() => _send(
    edited: AiMessage(
      role: AiRole.user,
      text: 'Continue the previous answer from where it stopped. Do not repeat the existing text.',
    ),
  );
  Future<void> _redirect({bool answerNow = false}) async {
    final instruction = answerNow
        ? 'Give the final answer now, concisely. Use the work above and do not repeat the reasoning.'
        : await _editText(
            'Add instructions',
            '',
            action: 'Restart with instructions',
            note: 'The current response will be stopped and preserved. A new request will use your instruction.',
          );
    if (!mounted || instruction == null || instruction.trim().isEmpty) return;
    if (answerNow) {
      _nextResponseSettings = AiSettings.fromJson({
        ..._preferences.settings.toJson(),
        'thinking': false,
      });
    }
    await _chat!.redirect(
      instruction,
      profileId: _profileId,
      provider: _profile?.kind.name,
      model: _profile?.modelId,
    );
  }

  void _queueDraft() {
    if (_profileId == null ||
        (_composer.text.trim().isEmpty && _attachments.isEmpty)) {
      return;
    }
    final accepted = _chat!.enqueue(
      AiQueuedMessage(
        message: AiMessage(
          role: AiRole.user,
          text: _composer.text.trim(),
          attachments: List.of(_attachments),
          containsPrivateContext: _draftPrivate,
        ),
        profileId: _profileId!,
        provider: _profile?.kind.name,
        model: _profile?.modelId,
      ),
    );
    if (accepted) {
      _update(() {
        _composer.clear();
        _attachments.clear();
        _draftPrivate = false;
      });
    } else {
      _notice('Queue is full. Keep up to 10 messages.');
    }
  }

  AiSettingsStore? _settings;
  AiPreferences _preferences = AiPreferences();
  final _composer = TextEditingController(), _search = TextEditingController();
  final _scroll = ScrollController(debugLabel: 'ai-chat-messages');
  ScrollPosition? get _scrollPosition =>
      _scroll.positions.length == 1 ? _scroll.positions.single : null;
  bool _enterToSend = false;
  bool get _desktopPlatform => switch (Theme.of(context).platform) {
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS => true,
    _ => false,
  };
  void _submitComposer() {
    if (_syncing || _preparing || _chat == null) return;
    if (_chat!.busy) {
      _queueDraft();
    } else {
      unawaited(_send());
    }
  }

  KeyEventResult _composerKey(FocusNode _, KeyEvent event) {
    if ((event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.numpadEnter) ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        !_composer.value.composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      if (_enterToSend && !HardwareKeyboard.instance.isShiftPressed) {
        _submitComposer();
      } else {
        final value = _composer.value;
        final start = value.selection.isValid
            ? value.selection.start
            : value.text.length;
        final end = value.selection.isValid
            ? value.selection.end
            : value.text.length;
        _composer.value = value.copyWith(
          text: value.text.replaceRange(start, end, '\n'),
          selection: TextSelection.collapsed(offset: start + 1),
          composing: TextRange.empty,
        );
      }
    }
    return KeyEventResult.handled;
  }

  final _attachments = <AiAttachment>[];
  String? _profileId, _error;
  bool _syncEnabled = false, _syncing = false, _replyNotifications = true;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  Timer? _debounce;
  bool _framePending = false, _preparing = false, _draftPrivate = false;
  AiCancellationToken? _preparationToken;
  int? _draftRetryIndex;
  List<AiMessage>? _lastPrompt;
  String? _lastPromptChatId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didHaveMemoryPressure() {
    aiDocumentTextCache.clear();
    _messageWidgets.clear();
    final local = _loadedLocalModels;
    if (local != null && !local.busy && _chat?.busy != true) {
      unawaited(local.unload().catchError((Object _) {}));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
  }

  Future<void> _init() async {
    try {
      if (mounted) setState(() => _error = null);
      // Only small chat preferences/storage reads gate entry. Model restore,
      // hashing, hardware probes and memory are deferred until a request.
      final (store, settings, enabled, notifications) = await (() async {
        final store = widget.store ?? await sharedAiChatStore();
        final settings =
            widget.settings ??
            AiSettingsStore(preferences: await SharedPreferences.getInstance());
        final enabled = await store.syncEnabled;
        final notifications = await store.replyNotificationsEnabled;
        return (store, settings, enabled, notifications);
      })().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      _settings = settings;
      _workspace = AiWorkspaceStore(settings.preferences);
      _sidebarCollapsed = _workspace!.sidebarCollapsed;
      _sidebarWidth = _workspace!.sidebarWidth;
      _inspector = _workspace!.inspector;
      _enterToSend = _workspace!.enterToSend;
      _composer.text = _workspace!.draft(null);
      _composer.removeListener(_draftChanged);
      _composer.addListener(_draftChanged);
      _preferences = settings.load();
      _profileId = _preferences.selectedProfileId;
      _chat = AiChatController(
        store: store,
        engine:
            widget.engine ??
            ({
              required message,
              required history,
              required profileId,
              required cancellationToken,
            }) => _configuredStream(
              settings: settings,
              store: store,
              message: message,
              history: history,
              profileId: profileId,
              cancellationToken: cancellationToken,
            ),
      );
      _chat!.addListener(_changed);
      _syncEnabled = enabled;
      _replyNotifications = notifications;
      // A slow history read must not hide the composer or the back button.
      final chat = _chat!;
      setState(() {});
      unawaited(
        chat.refresh().timeout(const Duration(seconds: 15)).catchError((
          Object _,
        ) {
          if (!mounted || !identical(_chat, chat)) return;
          chat.status = 'Unable to load chat history. Check storage and retry from Search.';
          _changed();
        }),
      );
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
    final follow = (_scrollPosition?.pixels ?? 0) < 160;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _framePending = false;
      if (!mounted) return;
      setState(() {});
      if (follow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollPosition?.jumpTo(0);
          }
        });
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  AiProviderProfile? get _profile =>
      _preferences.profiles.where((p) => p.id == _profileId).firstOrNull;
  Future<void> _settingsPage() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AiSettingsScreen(
          store: _settings,
          promptPreview: _showPrompts,
          localModels: _getLocalModels,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _preferences = _settings!.load();
      _enterToSend = _workspace!.enterToSend;
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

  Future<void> _select(AiConversation c) async {
    if (_preparing) return;
    _saveDraft();
    await _chat!.select(c.id);
    if (!mounted) return;
    setState(() {
      _profileId =
          _preferences.profiles.any((p) => p.id == _chat!.active?.profileId)
          ? _chat!.active!.profileId
          : _preferences.selectedProfileId;
      _attachments.clear();
      _composer.text = _workspace?.draft(c.id) ?? '';
      _draftPrivate = false;
      _draftRetryIndex = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollPosition?.jumpTo(0);
    });
  }

  String? _capabilitiesKey;
  AiCapabilities? _capabilities;
  AiCapabilities _inputCapabilities() {
    final key = '${_profile!.kind}:${_profile!.modelId}';
    if (_capabilitiesKey == key && _capabilities != null) return _capabilities!;
    _capabilitiesKey = key;
    if (_profile!.kind == AiProviderKind.offline) {
      return _capabilities =
          _offlineCapabilities?.call(_profile!.modelId) ??
          AiCapabilities(contextWindow: true);
    }
    final provider = _profile!.createProvider(credentials: () async => null);
    try {
      return _capabilities = provider.capabilitiesFor(_profile!.modelId);
    } finally {
      if (provider is HttpAiProvider) provider.close();
    }
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
    final draftChatId = _chat!.active?.id;
    final retryIndex = retryUserIndex ?? _draftRetryIndex;
    AiMessage? prepared;
    final settings = _responseSettings();
    final preparationToken = _preparationToken = AiCancellationToken();
    setState(() => _preparing = true);
    try {
      prepared = await prepareAiInput(
        message,
        _inputCapabilities(),
        cancellationToken: preparationToken,
      );
      if (_profile!.kind != AiProviderKind.offline) {
        checkAiInputBudget(prepared, settings);
      }
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
      _preparationToken = null;
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
          unawaited(_workspace!.saveDraft(draftChatId, ''));
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

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _buildWorkspace(context, width: constraints.maxWidth),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _draftTimer?.cancel();
    _saveDraft();
    _composer.removeListener(_draftChanged);
    _composerFocus.dispose();
    _searchFocus.dispose();
    _preparationToken?.cancel();
    _chat?.removeListener(_changed);
    _chat?.dispose();
    _composer.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }
}
