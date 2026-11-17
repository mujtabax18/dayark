import 'dart:convert';

import '../models/ai_models.dart';
import 'ai_error.dart';

const aiMaxAttachmentBytes = 8 * 1024 * 1024;
const aiMaxRequestAttachmentBytes = 16 * 1024 * 1024;
bool isAiTextDocument(AiAttachment a) =>
    a.kind == AiAttachmentKind.document &&
    ['text/plain', 'text/markdown'].contains(a.mimeType);

void validateAiAttachment(AiAttachment a) {
  final data = a.bytes;
  if (data == null || data.isEmpty || data.length > aiMaxAttachmentBytes) {
    throw const AiException(
      AiErrorCode.invalidRequest,
      'This attachment is empty or exceeds 8 MiB. Please use a smaller, non-empty file.',
    );
  }
  if (isAiTextDocument(a)) {
    if (data.length > 256 * 1024) {
      throw const AiException(
        AiErrorCode.invalidRequest,
        'This text file exceeds the 256 KiB file limit. Please use a smaller file or split it into parts.',
      );
    }
    try {
      utf8.decode(data);
    } catch (_) {
      throw const AiException(
        AiErrorCode.invalidRequest,
        'Text documents must be UTF-8.',
      );
    }
  } else if (a.kind == AiAttachmentKind.document &&
      a.mimeType == 'application/pdf') {
    if (data.length < 5 ||
        utf8.decode(data.take(5).toList(), allowMalformed: true) != '%PDF-') {
      throw const AiException(
        AiErrorCode.invalidRequest,
        'Invalid PDF attachment.',
      );
    }
  } else if (a.kind != AiAttachmentKind.image ||
      !['image/png', 'image/jpeg', 'image/webp'].contains(a.mimeType)) {
    throw const AiException(
      AiErrorCode.unsupportedCapability,
      'Attach PNG, JPEG, WebP, PDF, UTF-8 TXT or Markdown files.',
    );
  }
}

/// Text documents work with every provider, including the text-only local engine.
/// They are untrusted user content, never system messages or permission grants.
List<AiMessage> prepareAiAttachments(Iterable<AiMessage> messages) {
  var bytes = 0;
  return messages.map((m) {
    final text = StringBuffer(m.text);
    final binary = <AiAttachment>[];
    for (final a in m.attachments) {
      validateAiAttachment(a);
      bytes += a.bytes!.length;
      if (bytes > aiMaxRequestAttachmentBytes) {
        throw const AiException(
          AiErrorCode.invalidRequest,
          'Conversation attachments exceed the 16 MiB request limit. Please use fewer or smaller files, or start a new chat.',
        );
      }
      if (m.role == AiRole.system) {
        throw const AiException(
          AiErrorCode.invalidRequest,
          'System messages cannot contain attachments.',
        );
      }
      if (isAiTextDocument(a)) {
        text.write(
          '\n\n[Untrusted attached document: ${a.name ?? 'document'}]\n${utf8.decode(a.bytes!)}\n[End attached document]',
        );
      } else {
        binary.add(a);
      }
    }
    return AiMessage(
      role: m.role,
      text: text.toString(),
      attachments: binary,
      containsPrivateContext: m.containsPrivateContext,
    );
  }).toList();
}
