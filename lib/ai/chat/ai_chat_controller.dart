import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/ai_cancellation.dart';
import '../core/ai_error.dart';
import '../core/ai_stream.dart';
import '../models/ai_models.dart';
import 'ai_chat_store.dart';
import 'ai_conversation.dart';

typedef AiChatStream = Stream<AiStreamEvent> Function({
  required AiMessage message,
  required Iterable<AiMessage> history,
  required String? profileId,
  required AiCancellationToken cancellationToken,
});

class AiChatController extends ChangeNotifier {
  AiChatController({required this.store, required this.engine}) {
    _subscription = store.changes.listen((_) {
      if (!_disposed) unawaited(refresh());
    });
  }
  final AiChatStore store;
  final AiChatStream engine;
  late final StreamSubscription<void> _subscription;
  AiConversation? active;
  List<AiConversation> conversations = [];
  List<AiChatFolder> folders = [];
  bool busy = false, showArchived = false;
  String query = '';
  String? folder, status;
  String? activity;
  String thinkingText = '';
  AiCancellationToken? _token;
  bool _disposed = false;
  Timer? _streamPublish;
  int _selectionVersion = 0, _refreshVersion = 0;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    final version = ++_refreshVersion;
    final folderList = await store.folders();
    final value = await store.list(
      query: query,
      archived: showArchived,
      folder: folder,
      summaries: true,
    );
    if (_disposed || version != _refreshVersion) return;
    if (!busy && active != null) {
      final selected = active;
      final selectionVersion = _selectionVersion;
      final latest = await store.get(selected!.id);
      if (_disposed || version != _refreshVersion) return;
      // Navigation, edits or generation may have happened during the read.
      if (!busy &&
          selectionVersion == _selectionVersion &&
          identical(active, selected)) {
        active = latest == null || latest.deleted ? null : latest;
      }
    }
    folders = folderList;
    conversations = value;
    _notify();
  }

  Future<void> select(String id) async {
    if (busy || _disposed) return;
    final version = ++_selectionVersion;
    var value = await store.get(id);
    if (_disposed || busy || version != _selectionVersion) return;
    if (value == null || value.deleted) {
      active = null;
      _notify();
      return;
    }
    if (value.messages.any((m) => m.state == AiChatMessageState.pending)) {
      value = await store.save(
        value.copyWith(
          messages: value.messages.map(
            (m) => m.state == AiChatMessageState.pending
                ? m.copyWith(
                    state: AiChatMessageState.stopped,
                    error:
                        'Interrupted when the app closed. Retry to continue.',
                  )
                : m,
          ),
        ),
        expectedRevision: value.revision,
      );
    }
    if (_disposed || busy || version != _selectionVersion) return;
    active = value;
    thinkingText = '';
    status = null;
    _notify();
  }

  void newChat() {
    if (busy) return;
    ++_selectionVersion;
    active = null;
    thinkingText = '';
    status = null;
    _notify();
  }

  Future<void> _persist(AiConversation c) async {
    try {
      active = await store.save(c, expectedRevision: c.revision);
    } on AiChatConflict {
      final latest = await store.get(c.id);
      if (latest?.deleted ?? false) {
        throw StateError('Conversation was deleted on another device.');
      }
      active = await store.save(
        AiConversation(
          id: const Uuid().v4(),
          title:
              '${c.title.substring(0, c.title.length.clamp(0, 175))} (local copy)',
          updatedAt: DateTime.now().toUtc(),
          messages: c.messages,
          profileId: c.profileId,
        ),
        expectedRevision: 0,
      );
      status = 'This chat changed on another device. Your response was saved in a private local copy.';
    }
    _notify();
  }

  Future<void> update({
    String? title,
    String? folder,
    bool? pinned,
    bool? archived,
    String? profileId,
    bool? shareWithDevices,
  }) async {
    if (busy || active == null) return;
    await _persist(
      active!.copyWith(
        title: title,
        folder: folder,
        pinned: pinned,
        archived: archived,
        profileId: profileId,
        shareWithDevices: shareWithDevices,
      ),
    );
    await refresh();
  }

  Future<void> remove() async {
    if (busy || active == null) return;
    await store.delete(active!);
    active = null;
    await refresh();
    _notify();
  }

  Future<bool> send(
    AiMessage message, {
    required String? profileId,
    String? provider,
    String? model,
    int? retryUserIndex,
    VoidCallback? onAccepted,
  }) async {
    if (busy) return false;
    if (profileId == null) {
      status = 'Add and select a provider profile in AI settings first.';
      _notify();
      return false;
    }
    var accepted = false;
    ++_selectionVersion;
    busy = true;
    status = null;
    activity = 'Waiting for model…';
    thinkingText = '';
    _token = AiCancellationToken();
    _notify();
    try {
      var c =
          active ??
          AiConversation(
            id: const Uuid().v4(),
            title: 'New chat',
            updatedAt: DateTime.now().toUtc(),
            profileId: profileId,
            folder: folder ?? '',
            shareWithDevices: await store.syncEnabled,
          );
      final previous = retryUserIndex == null
          ? c.messages
          : c.messages.take(retryUserIndex).toList();
      final user = AiChatMessage(
        id: const Uuid().v4(),
        message: message,
        createdAt: DateTime.now().toUtc(),
      );
      final reply = AiChatMessage(
        id: const Uuid().v4(),
        message: AiMessage(role: AiRole.assistant, text: '…'),
        createdAt: DateTime.now().toUtc(),
        state: AiChatMessageState.pending,
        provider: provider,
        model: model,
      );
      c = c.copyWith(
        profileId: profileId,
        title: c.title == 'New chat'
            ? (message.text.trim().isEmpty
                  ? 'Attachment conversation'
                  : message.text.trim().substring(
                      0,
                      message.text.trim().length.clamp(0, 60),
                    ))
            : c.title,
        messages: [...previous, user, reply],
      );
      await _persist(c);
      accepted = true;
      onAccepted?.call();
      final history = previous
          .where(
            (m) =>
                m.state == AiChatMessageState.complete &&
                (m.message.text.trim().isNotEmpty ||
                    m.message.attachments.isNotEmpty),
          )
          .map((m) => m.message)
          .toList();
      final buffer = StringBuffer();
      final thinking = StringBuffer();
      final providerDiagnostics = StringBuffer();
      final watch = Stopwatch()..start();
      AiResponse? complete;
      var dirty = false;
      var eventsSinceYield = 0;
      final workSlice = Stopwatch()..start();
      void publish() {
        _streamPublish?.cancel();
        _streamPublish = null;
        if (!dirty || _disposed || active == null) return;
        dirty = false;
        if (thinkingText.length != thinking.length) {
          thinkingText = thinking.toString();
        }
        active = active!.copyWith(
          messages: [
            ...active!.messages.take(active!.messages.length - 1),
            reply.copyWith(
              message: AiMessage(
                role: AiRole.assistant,
                text: buffer.isEmpty ? '…' : buffer.toString(),
              ),
            ),
          ],
        );
        _notify();
      }

      void schedulePublish() {
        dirty = true;
        if (_streamPublish != null) return;
        final size = buffer.length + thinking.length;
        // Snapshot large strings less often; receipt of every fragment is unchanged.
        final milliseconds = size > 128 * 1024
            ? 200
            : size > 16 * 1024
            ? 100
            : 50;
        _streamPublish = Timer(Duration(milliseconds: milliseconds), publish);
      }

      try {
        await for (final event in engine(
          message: message,
          history: history,
          profileId: profileId,
          cancellationToken: _token!,
        )) {
          // A fast socket or buffered stream can otherwise monopolize microtasks.
          // Yield to input, painting and cancellation without discarding any output.
          if (++eventsSinceYield >= 64 || workSlice.elapsedMilliseconds >= 8) {
            await Future<void>.delayed(Duration.zero);
            eventsSinceYield = 0;
            workSlice.reset();
          }
          _token!.throwIfCancelled();
          if (event.isActivity) {
            activity = event.thinking?.isNotEmpty == true
                ? 'Thinking…'
                : 'Model is working…';
            if (event.thinking case final value? when value.isNotEmpty) {
              thinking.write(value);
            }
            if (event.diagnostic case final value? when value.isNotEmpty) {
              _appendBounded(providerDiagnostics, value);
            }
            schedulePublish();
            if (thinking.isNotEmpty &&
                thinking.length == event.thinking?.length) {
              publish();
            }
          }
          if (event.response != null) {
            complete = event.response;
          } else {
            buffer.write(event.text);
            if (event.text.isNotEmpty) activity = 'Receiving response…';
          }
          if (event.text.isNotEmpty) {
            schedulePublish();
            if (buffer.length == event.text.length) publish();
          }
        }
        publish();
        _token!.throwIfCancelled();
        if (complete == null) {
          throw const AiException(
            AiErrorCode.invalidResponse,
            'The response ended before completion.',
          );
        }
        final finished = AiChatMessage(
          id: reply.id,
          message: complete.message,
          thinkingOnly: complete.thinkingOnly,
          createdAt: reply.createdAt,
          provider: provider ?? complete.selection.providerId,
          model: complete.selection.modelId,
          elapsedMilliseconds: watch.elapsedMilliseconds,
          thinking: thinking.isEmpty ? null : thinking.toString(),
        );
        await _persist(
          active!.copyWith(
            messages: [
              ...active!.messages.take(active!.messages.length - 1),
              finished,
            ],
          ),
        );
      } catch (error) {
        publish();
        final cancelled = _token!.isCancelled;
        final safe = cancelled
            ? 'Response stopped. Retry to generate again.'
            : error is AiException
            ? error.message
            : 'Unable to complete response. Retry this message.';
        status = safe;
        final details = _failureDetails(
          error: error,
          provider: provider,
          model: model,
          elapsed: watch.elapsed,
          thinking: thinking.toString(),
          response: buffer.toString(),
          providerDiagnostics: providerDiagnostics.toString(),
        );
        final failed = reply.copyWith(
          state: cancelled
              ? AiChatMessageState.stopped
              : AiChatMessageState.failed,
          message: AiMessage(
            role: AiRole.assistant,
            text: buffer.isEmpty ? safe : buffer.toString(),
          ),
          error: safe,
          diagnostics: details,
          elapsedMilliseconds: watch.elapsedMilliseconds,
          thinking: thinking.isEmpty ? null : thinking.toString(),
        );
        await _persist(
          active!.copyWith(
            messages: [
              ...active!.messages.take(active!.messages.length - 1),
              failed,
            ],
          ),
        );
      }
    } on FormatException catch (error) {
      status = error.message;
    } catch (_) {
      status = 'Unable to save this chat. Check storage and retry.';
    } finally {
      _streamPublish?.cancel();
      _streamPublish = null;
      busy = false;
      activity = null;
      _token = null;
      await refresh();
      _notify();
    }
    return accepted;
  }

  void stop() => _token?.cancel();

  static void _appendBounded(StringBuffer target, String value) {
    const limit = 64 * 1024;
    if (target.length >= limit) return;
    final remaining = limit - target.length;
    target.write(value.substring(0, value.length.clamp(0, remaining)));
  }

  static String _failureDetails({
    required Object error,
    required String? provider,
    required String? model,
    required Duration elapsed,
    required String thinking,
    required String response,
    required String providerDiagnostics,
  }) {
    final code = error is AiException ? error.code.name : error.runtimeType;
    return <String>[
      'Provider: ${provider ?? 'unknown'}',
      'Model: ${model ?? 'unknown'}',
      'Result: $code',
      'Elapsed: ${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)} seconds',
      if (providerDiagnostics.isNotEmpty) providerDiagnostics,
      '',
      'MODEL THINKING',
      thinking.trim().isEmpty
          ? 'The provider did not expose any thinking text.'
          : thinking.trim(),
      '',
      'RESPONSE RECEIVED',
      response.trim().isEmpty
          ? 'The provider returned no visible answer text.'
          : response.trim(),
    ].join('\n');
  }

  @override
  void dispose() {
    _disposed = true;
    _streamPublish?.cancel();
    _token?.cancel();
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
