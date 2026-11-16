import 'ai_http_transport.dart';
import 'http_ai_provider.dart';

class GeminiProvider extends HttpAiProvider {
  GeminiProvider({
    super.id = 'gemini',
    Uri? baseUrl,
    required AiCredentialLoader super.credentials,
    super.allowInsecureHttp,
    super.modelCapabilities,
  }) : super(
         protocol: AiHttpProtocol.gemini,
         baseUrl:
             baseUrl ??
             Uri.parse('https://generativelanguage.googleapis.com/v1beta/'),
       );
}
