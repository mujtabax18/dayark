import '../models/ai_models.dart';
import '../models/ai_request.dart';
import 'ai_cancellation.dart';
import 'ai_capabilities.dart';

abstract interface class AiProvider {
  String get id;

  /// True for any processing outside the device, including custom servers.
  bool get isRemote;
  AiCapabilities capabilitiesFor(String modelId);

  /// Translate provider errors into safe AiExceptions; retry only transient ones.
  Future<AiResponse> generate(
    AiRequest request, {
    required AiCancellationToken cancellationToken,
  });
}
