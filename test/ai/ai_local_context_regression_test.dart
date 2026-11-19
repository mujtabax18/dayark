import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metersystem/ai/settings/ai_settings_store.dart';
import 'package:metersystem/ai/settings/ai_configured_assistant.dart';
import 'package:llamadart/llamadart.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/core/ai_input_preparation.dart';
import 'package:metersystem/ai/providers/offline/llamadart_runtime.dart';

class CapturingRuntime implements AiOfflineRuntime {
  AiRequest? request;
  @override
  Future<void> load(AiLocalModel model, AiCancellationToken token) async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<AiResponse> generate(
    AiRequest value,
    AiCancellationToken token,
  ) async {
    request = value;
    return AiResponse(
      selection: value.selection,
      message: AiMessage(role: AiRole.assistant, text: 'Hello!'),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('configured local chat sends hello despite shared output cap equalling context', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AiSettingsStore(
      preferences: await SharedPreferences.getInstance(),
    );
    await store.save(
      AiPreferences(
        profiles: [
          AiProviderProfile(
            id: 'local',
            name: 'Small model',
            kind: AiProviderKind.offline,
            modelId: '360m',
          ),
        ],
        selectedProfileId: 'local',
        settings: AiSettings(
          contextWindowTokens: 2048,
          maxOutputTokens: 2048,
          sendAdditionalPrompt: false,
        ),
      ),
    );
    final runtime = CapturingRuntime();
    final provider = OfflineAiProvider(
      models: [
        AiLocalModel(id: '360m', path: '/fixture.gguf', contextSize: 2048),
      ],
      runtime: runtime,
    );
    addTearDown(provider.dispose);
    List<AiMessage>? prepared;
    final response = await AiConfiguredAssistant(store).send(
      message: AiMessage(role: AiRole.user, text: 'hello'),
      offline: provider,
      onPreparedMessages: (messages) => prepared = messages,
    );
    expect(response.message.text, 'Hello!');
    expect(runtime.request!.messages.single.text, 'hello');
    expect(prepared, runtime.request!.messages);
    expect(runtime.request!.settings.maxOutputTokens, isNull);
  });

  LlamaChatMessage message(LlamaChatRole role, String text) =>
      LlamaChatMessage.fromText(role: role, text: text);

  test('small context accepts hello using model token count', () async {
    final input = [message(LlamaChatRole.user, 'hello')];
    final fitted = await fitLocalChatContext(
      input,
      contextSize: 2048,
      countTokens: (_) async => 7,
    );
    expect(fitted, input);
  });

  test(
    'tokenized overflow removes old exchanges and keeps current input',
    () async {
      final system = message(LlamaChatRole.system, 'Instructions');
      final current = message(LlamaChatRole.user, 'Current message');
      final input = [
        system,
        message(LlamaChatRole.user, 'Old question'),
        message(LlamaChatRole.assistant, 'Old answer'),
        current,
      ];
      var calls = 0;
      final fitted = await fitLocalChatContext(
        input,
        contextSize: 2048,
        countTokens: (messages) async {
          calls++;
          return messages.length > 2 ? 2050 : 20;
        },
      );
      expect(fitted, [system, current]);
      expect(input, hasLength(4));
      expect(calls, 2);
    },
  );

  test(
    'genuine token overflow gives an actionable error without clipping input',
    () async {
      await expectLater(
        fitLocalChatContext(
          [message(LlamaChatRole.user, 'Large input')],
          contextSize: 2048,
          countTokens: (_) async => 2055,
        ),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('2055 input tokens'),
          ),
        ),
      );
    },
  );

  test(
    'plain chat preference survives persistence and capability filtering',
    () {
      final settings = settingsForCapabilities(
        AiSettings.fromJson(
          AiSettings(
            sendAdditionalPrompt: false,
            customInstructions: 'Extra instructions',
            responseLanguage: 'Urdu',
            inputLanguage: 'English',
          ).toJson(),
        ),
        AiCapabilities(),
      );
      final user = AiMessage(role: AiRole.user, text: 'hello');
      final built = const PromptManager().build(
        settings: settings,
        history: const [],
        message: user,
      );
      expect(settings.sendAdditionalPrompt, isFalse);
      expect(built, [user]);
      expect(AiSettings.fromJson({}).sendAdditionalPrompt, isTrue);
    },
  );

  test(
    'reference instructions are added only for actual retrieved context',
    () {
      final built = const PromptManager().build(
        settings: AiSettings(sendAdditionalPrompt: false),
        history: const [],
        message: AiMessage(role: AiRole.user, text: 'Read'),
        retrievedContext: '{"fact":"cedar"}',
      );
      expect(
        built.where((m) => m.role == AiRole.system).single.text,
        PromptManager.retrievalInstructions,
      );
    },
  );
  test('disabled instructions do not consume the remote input allowance', () {
    expect(
      aiInputBudget(
        AiSettings(
          sendAdditionalPrompt: false,
          customInstructions: 'unused' * 2000,
        ),
      ),
      aiInputBudget(AiSettings(sendAdditionalPrompt: false)),
    );
    expect(aiAdditionalPromptBytes(AiSettings(sendAdditionalPrompt: false)), 0);
  });
}
