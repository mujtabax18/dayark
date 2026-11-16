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
  bool busy = false, showArchived = false;
  String query = '';
  String? folder, status;
  AiCancellationToken? _token;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    final value = await store.list(
      query: query,
      archived: showArchived,
      folder: folder,
      summaries: true,
    );
    if (_disposed) return;
    if (!busy && active != null) {
      final latest = await store.get(active!.id);
      if (_disposed) return;
      active = latest == null || latest.deleted ? null : latest;
    }
    conversations = value;
    _notify();
  }

  Future<void> select(String id) async {
    if (busy) return;
    var value = await store.get(id);
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
    active = value;
    status = null;
    _notify();
  }

  void newChat() {
    if (busy) return;
    active = null;
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
  }) async {
    if (busy) return false;
    if (profileId == null) {
      status = 'Add and select a provider profile in AI settings first.';
      _notify();
      return false;
    }
    var accepted = false;
    busy = true;
    status = null;
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
      final history = previous
          .where((m) => m.state == AiChatMessageState.complete)
          .map((m) => m.message)
          .toList();
      final buffer = StringBuffer();
      AiResponse? complete;
      try {
        await for (final event in engine(
          message: message,
          history: history,
          profileId: profileId,
          cancellationToken: _token!,
        )) {
          _token!.throwIfCancelled();
          if (event.response != null) {
            complete = event.response;
          } else {
            buffer.write(event.text);
          }
          if (buffer.isNotEmpty) {
            active = active!.copyWith(
              messages: [
                ...active!.messages.take(active!.messages.length - 1),
                reply.copyWith(
                  message: AiMessage(
                    role: AiRole.assistant,
                    text: buffer.toString(),
                  ),
                ),
              ],
            );
            _notify();
          }
        }
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
          createdAt: reply.createdAt,
          provider: provider ?? complete.selection.providerId,
          model: complete.selection.modelId,
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
        final cancelled = _token!.isCancelled;
        final safe = cancelled
            ? 'Response stopped. Retry to generate again.'
            : error is AiException
            ? error.message
            : 'Unable to complete response. Retry this message.';
        status = safe;
        final failed = reply.copyWith(
          state: cancelled
              ? AiChatMessageState.stopped
              : AiChatMessageState.failed,
          message: AiMessage(
            role: AiRole.assistant,
            text: buffer.isEmpty ? safe : buffer.toString(),
          ),
          error: safe,
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
      busy = false;
      _token = null;
      await refresh();
      _notify();
    }
    return accepted;
  }

  void stop() => _token?.cancel();
  @override
  void dispose() {
    _disposed = true;
    _token?.cancel();
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
