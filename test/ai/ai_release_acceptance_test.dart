import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/chat/ai_chat_controller.dart';
import 'package:metersystem/ai/chat/ai_chat_store.dart';
import 'package:metersystem/ai/chat/ai_conversation.dart';
import 'package:metersystem/ai/memory/memory_context_service.dart';
import 'package:metersystem/ai/memory/memory_store.dart';
import 'package:metersystem/ai/settings/ai_configured_assistant.dart';
import 'package:metersystem/ai/settings/ai_settings_store.dart';

import 'ai_foundation_test.dart' show FakeProvider;

// Part 8 integration gate. These fixtures test wiring and privacy, not model quality.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AiChatStore chats;
  late MemoryManager memory;
  late AiSettingsStore settings;
  late FakeProvider local;
  late AiChatController controller;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    chats = AiChatStore(AiChatDatabase(NativeDatabase.memory()));
    memory = MemoryManager(AiMemoryDatabase(NativeDatabase.memory()));
    settings = AiSettingsStore(
      preferences: await SharedPreferences.getInstance(),
    );
    await settings.save(
      AiPreferences(
        profiles: [
          AiProviderProfile(
            id: 'small',
            name: 'Small',
            kind: AiProviderKind.offline,
            modelId: 'alpha',
          ),
          AiProviderProfile(
            id: 'large',
            name: 'Large',
            kind: AiProviderKind.offline,
            modelId: 'beta',
          ),
          AiProviderProfile(
            id: 'remote',
            name: 'Remote',
            kind: AiProviderKind.compatible,
            baseUrl: 'http://127.0.0.1:1/v1/',
            modelId: 'remote-model',
          ),
        ],
        selectedProfileId: 'small',
        allowOnlineProcessing: true,
        settings: AiSettings(
          contextWindowTokens: 8192,
          maxOutputTokens: 128,
          temperature: .4,
          customInstructions: 'Keep answers brief.',
        ),
      ),
    );
    local = FakeProvider();
    final assistant = AiConfiguredAssistant(
      settings,
      memory: MemoryContextService(memory, chats: chats),
    );
    controller = AiChatController(
      store: chats,
      engine:
          ({
            required message,
            required history,
            required profileId,
            required cancellationToken,
          }) => assistant.stream(
            message: message,
            history: history,
            profileId: profileId,
            cancellationToken: cancellationToken,
            offline: profileId == 'remote' ? null : local,
          ),
    );
  });
  tearDown(() async {
    controller.dispose();
    await chats.close();
    await memory.close();
  });

  test('saved multilingual chat continues across local models with shared settings', () async {
    const prompts = [
      'Help me plan my day.',
      'میرے دن کی منصوبہ بندی میں مدد کریں۔',
      'Mere din ki planning mein madad karein.',
    ];
    String? conversationId;
    for (var i = 0; i < prompts.length; i++) {
      final profile = i == 1 ? 'large' : 'small';
      expect(
        await controller.send(
          AiMessage(role: AiRole.user, text: prompts[i]),
          profileId: profile,
        ),
        isTrue,
      );
      conversationId ??= controller.active!.id;
      expect(controller.active!.id, conversationId);
      expect(
        controller.active!.messages.last.state,
        AiChatMessageState.complete,
      );
      final request = local.requests.last;
      expect(request.selection.modelId, i == 1 ? 'beta' : 'alpha');
      expect(request.settings.temperature, .4);
      expect(request.settings.maxOutputTokens, 128);
      expect(settings.load().settings.maxOutputTokens, 128);
      expect(
        request.messages.map((m) => m.text).join(),
        contains('Keep answers brief.'),
      );
      expect(
        request.messages.map((m) => m.text),
        containsAll(prompts.take(i + 1)),
      );
      // Reopen the saved chat to exercise the persistence boundary each turn.
      controller.newChat();
      await controller.select(conversationId);
    }
    final saved = (await chats.list()).single;
    expect(saved.messages, hasLength(6));
    expect(
      saved.messages
          .where((m) => m.message.role == AiRole.user)
          .map((m) => m.message.text),
      prompts,
    );
  });

  test('deleted knowledge stays private in saved answers after remote model switch', () async {
    await memory.put(
      id: 'private-reference',
      title: 'Private reference',
      kind: 'document',
      text: 'Orchard project has a private code: cedar.',
    );
    await memory.setSetting('rag', 'true');
    await controller.send(
      AiMessage(role: AiRole.user, text: 'Orchard project code?'),
      profileId: 'small',
    );
    final id = controller.active!.id;
    expect(
      controller.active!.messages.last.message.text,
      contains('dayark-source:private-reference'),
    );
    expect(
      controller.active!.messages.last.message.containsPrivateContext,
      isTrue,
    );
    await memory.delete('private-reference');
    await memory.setSetting('rag', 'false');
    expect(await memory.sources(), isEmpty);
    controller.newChat();
    await controller.select(id);
    await controller.send(
      AiMessage(role: AiRole.user, text: 'Repeat that answer.'),
      profileId: 'remote',
    );
    final saved = (await chats.get(id))!;
    expect(saved.messages, hasLength(4));
    expect(saved.messages.last.state, AiChatMessageState.failed);
    expect(saved.messages.last.diagnostics, contains('permissionDenied'));
    // An attempted socket call would fail with connectionFailed instead.
    expect(saved.messages[1].message.containsPrivateContext, isTrue);
    expect(local.requests, hasLength(1));
  });
}
