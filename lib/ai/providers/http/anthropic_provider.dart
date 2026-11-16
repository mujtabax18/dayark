import 'ai_http_transport.dart';
import 'http_ai_provider.dart';

class AnthropicProvider extends HttpAiProvider {
  AnthropicProvider({
    super.id = 'anthropic',
    Uri? baseUrl,
    required AiCredentialLoader super.credentials,
    super.allowInsecureHttp,
    super.modelCapabilities,
    super.anthropicVersion,
    super.defaultMaxOutputTokens,
  }) : super(
         protocol: AiHttpProtocol.anthropic,
         baseUrl: baseUrl ?? Uri.parse('https://api.anthropic.com/v1/'),
       );
}
