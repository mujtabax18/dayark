part of 'ai_chat_screen.dart';

extension _AiComposerView on _AiChatScreenState {
  Widget _composerView(bool compact) {
    final chat = _chat!;
    final scheme = Theme.of(context).colorScheme;
    final caps = _profile == null ? null : _inputCapabilities();
    final selected =
        AiPerformanceProfile.values
            .where((p) => p.name == _preferences.settings.performanceProfile)
            .firstOrNull ??
        AiPerformanceProfile.custom;
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: LayoutBuilder(
            builder: (context, constraints) => Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .7),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_nextResponseInstructions.isNotEmpty)
                    InputChip(
                      label: const Text('Next response instructions'),
                      onDeleted: () =>
                          _update(() => _nextResponseInstructions = ''),
                    ),
                  if (_attachments.isNotEmpty)
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final attachment in _attachments)
                            InputChip(
                              label: Text(attachment.name ?? 'Attachment'),
                              onDeleted: () => _update(
                                () => _attachments.remove(attachment),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Focus(
                      skipTraversal: true,
                      onKeyEvent: _composerKey,
                      child: TextField(
                        controller: _composer,
                        focusNode: _composerFocus,
                        enabled: !_syncing && !_preparing,
                        minLines: 1,
                        maxLines: compact ? 2 : 6,
                        textInputAction: _enterToSend
                            ? TextInputAction.send
                            : TextInputAction.newline,
                        onSubmitted: (_) {
                          if (_enterToSend) _submitComposer();
                        },
                        decoration: const InputDecoration(
                          hintText: 'Message DayArk…',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (caps != null)
                        IconButton(
                          tooltip: 'Attach files',
                          onPressed: _preparing ? null : () => _pick(),
                          icon: const Icon(Icons.add_rounded, size: 21),
                        ),
                      if (caps?.attachments.contains(AiAttachmentKind.image) ==
                              true &&
                          !chat.busy)
                        IconButton(
                          tooltip: 'Attach images',
                          onPressed: _preparing
                              ? null
                              : () => _pick(images: true),
                          icon: const Icon(Icons.image_outlined, size: 21),
                        ),
                      SizedBox(
                        width:
                            (constraints.maxWidth -
                                    44 -
                                    48 *
                                        ((caps != null ? 1 : 0) +
                                            (caps?.attachments.contains(
                                                          AiAttachmentKind
                                                              .image,
                                                        ) ==
                                                        true &&
                                                    !chat.busy
                                                ? 1
                                                : 0) +
                                            2 +
                                            (_profile != null && !compact
                                                ? 1
                                                : 0) +
                                            (chat.busy ? 1 : 0)))
                                .clamp(24, 110),
                        child: PopupMenuButton<AiPerformanceProfile>(
                          tooltip: 'Performance profile',
                          enabled: !chat.busy && !_preparing,
                          onSelected: _performance,
                          itemBuilder: (_) => [
                            for (final profile in AiPerformanceProfile.values)
                              PopupMenuItem(
                                value: profile,
                                child: Text(profile.label),
                              ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_outlined, size: 17),
                                Flexible(
                                  child: Text(
                                    selected.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      PopupMenuButton<int>(
                        tooltip: 'Prompt controls',
                        onSelected: (value) async {
                          if (value == 0) await _toggleExtraPrompt();
                          if (value == 1) await _instructions();
                          if (value == 2) await _showPrompts();
                          if (value == 3) await _promptLibrary();
                          if (value == 4) {
                            await _saveBehavior(
                              AiSettings.fromJson({
                                ..._preferences.settings.toJson(),
                                'useMemory': !_preferences.settings.useMemory,
                              }),
                            );
                          }
                          if (value == 5) {
                            final text = await _editText(
                              'Conversation instructions',
                              chat.active?.instructions ?? '',
                            );
                            if (text != null && mounted) {
                              await chat.update(instructions: text);
                            }
                          }
                          if (value == 6) {
                            final text = await _editText(
                              'Next response instructions',
                              _nextResponseInstructions,
                            );
                            if (text != null && mounted) {
                              _update(() => _nextResponseInstructions = text);
                            }
                          }
                          if (value >= 10 && value <= 12) {
                            await _saveBehavior(
                              AiSettings.fromJson({
                                ..._preferences.settings.toJson(),
                                'thinking': value == 10
                                    ? false
                                    : value == 11
                                    ? null
                                    : true,
                              }),
                            );
                          }
                          if (value == 7) {
                            final text = await _editText(
                              'Response language',
                              _preferences.settings.responseLanguage ?? '',
                            );
                            if (text != null && mounted) {
                              await _saveBehavior(
                                AiSettings.fromJson({
                                  ..._preferences.settings.toJson(),
                                  'responseLanguage': text.isEmpty
                                      ? null
                                      : text,
                                }),
                              );
                            }
                          }
                          if (value == 8) {
                            final text = await _editText(
                              'Unload after idle minutes (0 keeps loaded)',
                              '${_preferences.settings.idleTimeoutMinutes}',
                            );
                            final minutes = int.tryParse(text ?? '');
                            if (minutes != null && mounted) {
                              await _saveBehavior(
                                AiSettings.fromJson({
                                  ..._preferences.settings.toJson(),
                                  'idleTimeoutMinutes': minutes.clamp(0, 120),
                                }),
                              );
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 0,
                            enabled: !chat.busy,
                            child: Text(
                              _preferences.settings.sendAdditionalPrompt
                                  ? 'Disable extra prompt'
                                  : 'Enable extra prompt',
                            ),
                          ),
                          PopupMenuItem(
                            value: 1,
                            enabled: !chat.busy,
                            child: const Text('Your instructions'),
                          ),
                          const PopupMenuItem(
                            value: 2,
                            child: Text('View prompts'),
                          ),
                          const PopupMenuItem(
                            value: 3,
                            child: Text('Prompt library'),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 4,
                            enabled: !chat.busy,
                            child: Text(
                              _preferences.settings.useMemory
                                  ? 'Disable memory retrieval'
                                  : 'Enable memory retrieval',
                            ),
                          ),
                          PopupMenuItem(
                            value: 5,
                            enabled: !chat.busy && chat.active != null,
                            child: const Text('Conversation instructions'),
                          ),
                          const PopupMenuItem(
                            value: 6,
                            child: Text('Next response instructions'),
                          ),
                          PopupMenuItem(
                            value: 7,
                            enabled: !chat.busy,
                            child: const Text('Response language'),
                          ),
                          if (_profile?.kind == AiProviderKind.offline)
                            PopupMenuItem(
                              value: 8,
                              enabled: !chat.busy,
                              child: const Text('Model idle timeout'),
                            ),
                          if (caps?.thinking == true) ...[
                            PopupMenuItem(
                              value: 10,
                              enabled: !chat.busy,
                              child: const Text('Thinking: disabled'),
                            ),
                            PopupMenuItem(
                              value: 11,
                              enabled: !chat.busy,
                              child: const Text('Thinking: automatic'),
                            ),
                            PopupMenuItem(
                              value: 12,
                              enabled: !chat.busy,
                              child: const Text('Thinking: enabled'),
                            ),
                          ] else
                            const PopupMenuItem(
                              enabled: false,
                              child: Text('Thinking control unavailable'),
                            ),
                        ],
                        icon: const Icon(Icons.tune_rounded, size: 19),
                      ),
                      const Spacer(),
                      if (_profile != null && !compact)
                        IconButton(
                          tooltip: 'Voice input',
                          onPressed: _preparing
                              ? null
                              : () async {
                                  final text = await showDialog<String>(
                                    context: context,
                                    useRootNavigator: false,
                                    builder: (_) =>
                                        VoiceInputDialog(settings: _settings!),
                                  );
                                  if (mounted && text != null) {
                                    _composer.text = [
                                      _composer.text,
                                      text,
                                    ].where((s) => s.isNotEmpty).join('\n');
                                  }
                                },
                          icon: const Icon(Icons.mic_none, size: 21),
                        ),
                      if (chat.busy)
                        IconButton(
                          tooltip: 'Queue message',
                          onPressed: _queueDraft,
                          icon: const Icon(
                            Icons.playlist_add_rounded,
                            size: 22,
                          ),
                        ),
                      IconButton.filled(
                        tooltip: chat.busy || _preparing
                            ? 'Stop response'
                            : 'Send message',
                        onPressed: _syncing
                            ? null
                            : chat.busy
                            ? chat.stop
                            : _preparing
                            ? () => _preparationToken?.cancel()
                            : () => _send(),
                        icon: Icon(
                          chat.busy || _preparing
                              ? Icons.stop_rounded
                              : Icons.arrow_upward_rounded,
                          size: 22,
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
    );
  }

  Future<void> _saveBehavior(AiSettings settings) async {
    final current = _settings!.load();
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
      if (mounted) _notice('Unable to save response preferences.');
    }
  }

  Future<void> _toggleExtraPrompt() => _saveBehavior(
    AiSettings.fromJson({
      ..._preferences.settings.toJson(),
      'sendAdditionalPrompt': !_preferences.settings.sendAdditionalPrompt,
    }),
  );
  Future<void> _instructions() async {
    final text = await _editText(
      'Your instructions',
      _preferences.settings.customInstructions,
    );
    if (text != null && mounted) {
      await _saveBehavior(
        AiSettings.fromJson({
          ..._preferences.settings.toJson(),
          'customInstructions': text,
        }),
      );
    }
  }
}
