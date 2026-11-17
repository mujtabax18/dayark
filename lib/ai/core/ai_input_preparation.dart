import 'dart:convert';

import '../models/ai_models.dart';
import '../prompts/prompt_manager.dart';
import '../rag/document_ingestion.dart';
import '../settings/ai_settings.dart';
import 'ai_attachments.dart';
import 'ai_capabilities.dart';
import 'ai_error.dart';

class AiInputTooLarge extends AiException {
  AiInputTooLarge({
    required this.bytes,
    required this.budget,
    required this.contextTokens,
  }) : super(
         AiErrorCode.invalidRequest,
         'Your message, converted file text or voice transcript exceeds this model’s input budget '
         '($bytes UTF-8 bytes; $budget available with a $contextTokens-token context). '
         'Please use a smaller file or shorter message, increase the context size in AI settings, '
         'or summarize the text in parts first.',
       );
  final int bytes, budget, contextTokens;
}

/// Conservative UTF-8 budgeting, shared with the memory context builder.
int aiInputBudget(AiSettings settings) =>
    (settings.contextWindowTokens ?? 4096) -
    (settings.maxOutputTokens ?? 1024) -
    1024 -
    utf8.encode(settings.customInstructions).length -
    utf8.encode(PromptManager.retrievalInstructions).length;

void checkAiInputBudget(AiMessage prepared, AiSettings settings) {
  final budget = aiInputBudget(settings).clamp(0, 1 << 30);
  final bytes =
      utf8.encode(prepared.text).length + prepared.attachments.length * 1024;
  if (bytes > budget) {
    throw AiInputTooLarge(
      bytes: bytes,
      budget: budget,
      contextTokens: settings.contextWindowTokens ?? 4096,
    );
  }
}

/// PDF text extraction is local; no OCR or hidden upload is performed.
/// Text-only models receive extracted text rather than unsupported PDF bytes.
Future<AiMessage> prepareAiInput(
  AiMessage message,
  AiCapabilities capabilities,
) async {
  final text = StringBuffer(message.text);
  final attachments = <AiAttachment>[];
  for (final attachment in message.attachments) {
    validateAiAttachment(attachment);
    if (attachment.mimeType == 'application/pdf' &&
        !capabilities.attachments.contains(AiAttachmentKind.document)) {
      final extracted = await DocumentIngestion.extract(
        'attachment.pdf',
        attachment.bytes!,
      );
      text.write(
        '\n\n[Untrusted extracted PDF: ${attachment.name ?? 'document'}]\n$extracted\n[End extracted PDF]',
      );
    } else if (attachment.kind == AiAttachmentKind.image &&
        !capabilities.attachments.contains(AiAttachmentKind.image)) {
      throw const AiException(
        AiErrorCode.unsupportedCapability,
        'This model is configured for text input and cannot read images. '
        'Choose an image-capable model or attach a text document instead.',
      );
    } else {
      attachments.add(attachment);
    }
  }
  return prepareAiAttachments([
    AiMessage(
      role: message.role,
      text: text.toString(),
      attachments: attachments,
      containsPrivateContext: message.containsPrivateContext,
    ),
  ]).single;
}
