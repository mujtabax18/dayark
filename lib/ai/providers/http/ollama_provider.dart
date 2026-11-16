import 'http_ai_provider.dart';

class OllamaProvider extends HttpAiProvider {
  OllamaProvider({
    super.id = 'ollama',
    Uri? baseUrl,
    super.credentials,
    super.allowInsecureHttp,
    super.modelCapabilities,
  }) : super(
         protocol: AiHttpProtocol.ollama,
         baseUrl: baseUrl ?? Uri.parse('http://localhost:11434/api/'),
       );
}
