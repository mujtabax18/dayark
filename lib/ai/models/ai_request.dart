import 'dart:convert';

import '../settings/ai_settings.dart';
import 'ai_models.dart';

class AiRequest {
  AiRequest({
    required this.selection,
    required Iterable<AiMessage> messages,
    AiSettings? settings,
    this.allowRemoteProcessing = false,
    bool containsPrivateContext = false,
    this.allowPrivateContextOnline = false,
  }) : containsPrivateContext =
           containsPrivateContext ||
           messages.any((m) => m.containsPrivateContext),
       messages = List.unmodifiable(messages),
       settings = settings ?? AiSettings() {
    if (this.messages.isEmpty) {
      throw ArgumentError('Messages are required.');
    }
  }

  final AiModelSelection selection;
  final List<AiMessage> messages;
  final AiSettings settings;

  /// Explicit authorization for this request, including context/attachments.
  final bool allowRemoteProcessing;
  final bool containsPrivateContext;
  final bool allowPrivateContextOnline;

  Map<String, dynamic> toJson({bool includeBytes = false}) => {
    'selection': selection.toJson(),
    'settings': settings.toJson(),
    'allowRemoteProcessing': allowRemoteProcessing,
    'containsPrivateContext': containsPrivateContext,
    'allowPrivateContextOnline': allowPrivateContextOnline,
    'messageCount': messages.length,
    'messages': messages
        .map((m) => m.toJson(includeBytes: includeBytes))
        .toList(),
  };

  String toDebugString({bool includeBytes = false}) {
    final json = const JsonEncoder.withIndent('  ')
        .convert(toJson(includeBytes: includeBytes));

    return '''
========== AiRequest ==========
$json
===============================
''';
  }

  @override
  String toString() => toDebugString();
}
