import 'http_ai_provider.dart';

class CompatibleApiProvider extends HttpAiProvider {
  CompatibleApiProvider({
    super.id = 'compatible',
    required super.baseUrl,
    super.credentials,
    super.allowInsecureHttp,
    super.modelCapabilities,
    super.compatibleUsesCompletionTokens,
  }) : super(protocol: AiHttpProtocol.compatible);
}
