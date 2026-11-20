part of 'ai_chat_screen.dart';

extension _AiChatPreparation on _AiChatScreenState {
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
    _update(() {
      _composer.text = prompt;
      _attachments.clear();
      _draftPrivate = reduced!.containsPrivateContext;
      _draftRetryIndex = retryIndex;
    });
  }
}
