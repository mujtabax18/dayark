import 'dart:convert';
import 'dart:typed_data';

/// Provider-independent conversation values.
enum AiRole { system, user, assistant }

enum AiAttachmentKind { image, document, audio }

class AiAttachment {
  AiAttachment({
    required this.id,
    required this.kind,
    required this.mimeType,
    required this.uri,
    this.name,
    Uint8List? bytes,
  }) : bytes = bytes == null
           ? null
           : Uint8List.fromList(bytes).asUnmodifiableView() {
    if (id.trim().isEmpty || mimeType.trim().isEmpty) {
      throw ArgumentError('Attachment ID and MIME type are required.');
    }
  }

  final String id;
  final AiAttachmentKind kind;
  final String mimeType;

  /// A reference only; adapters must explicitly resolve supported resources.
  final Uri uri;
  final String? name;
  final Uint8List? bytes;

  Map<String, dynamic> toJson({bool includeBytes = false}) => {
    'id': id,
    'kind': kind.name,
    'mimeType': mimeType,
    'uri': uri.toString(),
    'name': name,
    'hasBytes': bytes != null,
    'bytesLength': bytes?.length,
    if (includeBytes) 'bytes': bytes?.toList(),
  };

  @override
  String toString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}

class AiMessage {
  AiMessage({
    required this.role,
    required this.text,
    this.containsPrivateContext = false,
    Iterable<AiAttachment> attachments = const [],
  }) : attachments = List.unmodifiable(attachments) {
    if (role != AiRole.assistant &&
        text.trim().isEmpty &&
        this.attachments.isEmpty) {
      throw ArgumentError('A message needs text or an attachment.');
    }
  }

  final AiRole role;
  final String text;
  final List<AiAttachment> attachments;

  /// Derived private context remains protected when history changes providers.
  final bool containsPrivateContext;

  Map<String, dynamic> toJson({bool includeBytes = false}) => {
    'role': role.name,
    'text': text,
    'textLength': text.length,
    'containsPrivateContext': containsPrivateContext,
    'attachmentCount': attachments.length,
    'attachments': attachments
        .map((a) => a.toJson(includeBytes: includeBytes))
        .toList(),
  };

  @override
  String toString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}

class AiModelSelection {
  AiModelSelection({required this.providerId, required this.modelId}) {
    if (providerId.trim().isEmpty || modelId.trim().isEmpty) {
      throw ArgumentError('Provider and model IDs are required.');
    }
  }

  final String providerId;
  final String modelId;

  Map<String, dynamic> toJson() => {
    'providerId': providerId,
    'modelId': modelId,
  };

  @override
  String toString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}

class AiUsage {
  const AiUsage({this.inputTokens, this.outputTokens});

  final int? inputTokens;
  final int? outputTokens;

  Map<String, dynamic> toJson() => {
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'totalTokens': inputTokens != null && outputTokens != null
        ? inputTokens! + outputTokens!
        : null,
  };

  @override
  String toString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}

class AiResponse {
  AiResponse({
    required this.selection,
    required this.message,
    this.usage = const AiUsage(),
    this.finishReason,
    this.thinkingOnly = false,
  }) {
    if (message.text.trim().isEmpty &&
        message.attachments.isEmpty &&
        !thinkingOnly) {
      throw ArgumentError(
        'An empty assistant response must be explicitly marked thinking-only.',
      );
    }

    if (message.role != AiRole.assistant) {
      throw ArgumentError('An AI response must be an assistant message.');
    }
  }

  final AiModelSelection selection;
  final AiMessage message;
  final AiUsage usage;
  final String? finishReason;

  /// A terminal response with streamed reasoning but no final answer.
  final bool thinkingOnly;

  Map<String, dynamic> toJson({bool includeBytes = false}) => {
    'selection': selection.toJson(),
    'message': message.toJson(includeBytes: includeBytes),
    'usage': usage.toJson(),
    'finishReason': finishReason,
    'thinkingOnly': thinkingOnly,
  };

  @override
  String toString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}
