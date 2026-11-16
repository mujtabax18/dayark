import '../models/ai_models.dart';

class AiCapabilities {
  AiCapabilities({
    Iterable<AiAttachmentKind> attachments = const [],
    this.temperature = true,
    this.maxTemperature,
    this.outputTokenLimit = true,
    this.contextWindow = false,
  }) : attachments = Set.unmodifiable(attachments);
  final Set<AiAttachmentKind> attachments;
  final bool temperature;
  final double? maxTemperature;
  final bool outputTokenLimit;
  final bool contextWindow;
}
