import 'dart:typed_data';

/// Provider-independent conversation values. No application records or secrets.
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
}

class AiMessage {
  AiMessage({
    required this.role,
    required this.text,
    Iterable<AiAttachment> attachments = const [],
  }) : attachments = List.unmodifiable(attachments) {
    if (text.trim().isEmpty && this.attachments.isEmpty) {
      throw ArgumentError('A message needs text or an attachment.');
    }
  }
  final AiRole role;
  final String text;
  final List<AiAttachment> attachments;
}

class AiModelSelection {
  AiModelSelection({required this.providerId, required this.modelId}) {
    if (providerId.trim().isEmpty || modelId.trim().isEmpty) {
      throw ArgumentError('Provider and model IDs are required.');
    }
  }
  final String providerId;
  final String modelId;
}

class AiUsage {
  const AiUsage({this.inputTokens, this.outputTokens});
  final int? inputTokens;
  final int? outputTokens;
}

class AiResponse {
  AiResponse({
    required this.selection,
    required this.message,
    this.usage = const AiUsage(),
    this.finishReason,
  }) {
    if (message.role != AiRole.assistant) {
      throw ArgumentError('An AI response must be an assistant message.');
    }
  }
  final AiModelSelection selection;
  final AiMessage message;
  final AiUsage usage;
  final String? finishReason;
}
