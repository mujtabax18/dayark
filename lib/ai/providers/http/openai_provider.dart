import 'ai_http_transport.dart';
import 'http_ai_provider.dart';

class OpenAiProvider extends HttpAiProvider {
  OpenAiProvider({
    super.id = 'openai',
    Uri? baseUrl,
    required AiCredentialLoader super.credentials,
    super.allowInsecureHttp,
    super.modelCapabilities,
  }) : super(
         protocol: AiHttpProtocol.openai,
         baseUrl: baseUrl ?? Uri.parse('https://api.openai.com/v1/'),
       );
}
