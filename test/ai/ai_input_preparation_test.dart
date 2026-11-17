import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/core/ai_input_preparation.dart';
import 'package:metersystem/ai/chat/ai_input_reduction.dart';
import 'package:pdf/widgets.dart' as pdf;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:metersystem/ai/settings/ai_settings_store.dart';
import 'package:metersystem/ai/settings/ai_configured_assistant.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('text and PDF convert locally for text models; unsupported images fail clearly', () async {
    final document = pdf.Document()
      ..addPage(
        pdf.Page(build: (_) => pdf.Text('Orchard project code is cedar.')),
      );
    AiAttachment attachment(
      String name,
      String mime,
      Uint8List data,
      AiAttachmentKind kind,
    ) => AiAttachment(
      id: name,
      name: name,
      mimeType: mime,
      bytes: data,
      kind: kind,
      uri: Uri(scheme: 'attachment', path: name),
    );
    final prepared = await prepareAiInput(
      AiMessage(
        role: AiRole.user,
        text: 'Read these',
        attachments: [
          attachment(
            'note.txt',
            'text/plain',
            Uint8List.fromList(utf8.encode('اردو متن')),
            AiAttachmentKind.document,
          ),
          attachment(
            'note.pdf',
            'application/pdf',
            await document.save(),
            AiAttachmentKind.document,
          ),
        ],
      ),
      AiCapabilities(),
    );
    expect(prepared.text, contains('اردو متن'));
    expect(prepared.text, contains('Orchard project code is cedar.'));
    expect(prepared.attachments, isEmpty);
    expect(prepared.text, contains('Untrusted extracted PDF'));
    await expectLater(
      prepareAiInput(
        AiMessage(
          role: AiRole.user,
          text: '',
          attachments: [
            attachment(
              'photo.png',
              'image/png',
              Uint8List.fromList([1]),
              AiAttachmentKind.image,
            ),
          ],
        ),
        AiCapabilities(),
      ),
      throwsA(
        isA<AiException>().having(
          (e) => e.message,
          'message',
          contains('cannot read images'),
        ),
      ),
    );
  });

  test(
    'oversized converted input explains byte budget and smaller input recovery',
    () async {
      final settings = AiSettings(
        contextWindowTokens: 4096,
        maxOutputTokens: 1024,
      );
      final message = AiMessage(role: AiRole.user, text: 'اردو' * 2000);
      expect(
        () => checkAiInputBudget(message, settings),
        throwsA(
          isA<AiInputTooLarge>()
              .having((e) => e.budget, 'budget', aiInputBudget(settings))
              .having(
                (e) => e.message,
                'message',
                contains('Please use a smaller file'),
              ),
        ),
      );
    },
  );

  test(
    'UTF-8 splitting covers every character without breaking Urdu or emoji',
    () {
      final original = 'اردو 🌱 متن ' * 300;
      final parts = AiInputReduction.splitUtf8(original, 257);
      expect(parts.join(), original);
      expect(parts.every((s) => utf8.encode(s).length <= 257), isTrue);
    },
  );

  test('summary covers all parts, reduces hierarchically, keeps privacy and fits final budget', () async {
    final source =
        'Original request: explain this. ${'اردو document facts 🌱 ' * 200} LAST FACT';
    final prompts = <String>[];
    final progress = <int>[];
    final result = await const AiInputReduction().summarize(
      prepared: AiMessage(
        role: AiRole.user,
        text: source,
        containsPrivateContext: true,
      ),
      budget: 800,
      partBudget: 1500,
      profileId: 'local',
      cancellationToken: AiCancellationToken(),
      onProgress: (part, total, pass) => progress.add(pass),
      engine:
          ({
            required message,
            required history,
            required profileId,
            required cancellationToken,
          }) async* {
            expect(history, isEmpty);
            expect(profileId, 'local');
            expect(message.containsPrivateContext, isTrue);
            expect(utf8.encode(message.text).length, lessThanOrEqualTo(1500));
            prompts.add(message.text);
            yield AiStreamEvent.completed(
              AiResponse(
                selection: AiModelSelection(
                  providerId: 'local',
                  modelId: 'small',
                ),
                message: AiMessage(
                  role: AiRole.assistant,
                  text: 'Key facts preserved. ' * 10,
                ),
              ),
            );
          },
    );
    final firstPass = prompts.takeWhile(
      (p) => !p.contains('Key facts preserved.'),
    );
    expect(firstPass.map((p) => p.split('Source:\n').last).join(), source);
    expect(progress, contains(2));
    expect(utf8.encode(result.text).length, lessThanOrEqualTo(800));
    expect(result.containsPrivateContext, isTrue);
  });

  test(
    'summary generation preserves online private-context permission checks',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final settings = AiSettingsStore(
        preferences: await SharedPreferences.getInstance(),
      );
      await settings.save(
        AiPreferences(
          profiles: [
            AiProviderProfile(
              id: 'remote',
              name: 'Remote',
              kind: AiProviderKind.compatible,
              baseUrl: 'http://127.0.0.1:1/v1/',
              modelId: 'test',
            ),
          ],
          selectedProfileId: 'remote',
          allowOnlineProcessing: true,
        ),
      );
      final assistant = AiConfiguredAssistant(settings);
      await expectLater(
        const AiInputReduction().summarize(
          prepared: AiMessage(
            role: AiRole.user,
            text: 'private facts ' * 200,
            containsPrivateContext: true,
          ),
          budget: 800,
          partBudget: 1500,
          profileId: 'remote',
          cancellationToken: AiCancellationToken(),
          onProgress: (_, _, _) {},
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
                settingsOverride: AiSettings(maxOutputTokens: 128),
              ),
        ),
        throwsA(
          isA<AiException>().having(
            (e) => e.code,
            'code',
            AiErrorCode.permissionDenied,
          ),
        ),
      );
    },
  );

  test('summary cancellation and failed shortening never return a truncated prompt', () async {
    final token = AiCancellationToken()..cancel();
    var calls = 0;
    engine({
      required message,
      required history,
      required profileId,
      required cancellationToken,
    }) async* {
      calls++;
      yield AiStreamEvent.completed(
        AiResponse(
          selection: AiModelSelection(providerId: 'local', modelId: 'small'),
          message: AiMessage(role: AiRole.assistant, text: 'Too long ' * 1000),
        ),
      );
    }

    Future<AiMessage> run(AiCancellationToken cancellation) =>
        const AiInputReduction().summarize(
          prepared: AiMessage(role: AiRole.user, text: 'source ' * 200),
          budget: 800,
          profileId: 'local',
          engine: engine,
          cancellationToken: cancellation,
          onProgress: (_, _, _) {},
        );
    await expectLater(
      run(token),
      throwsA(
        isA<AiException>().having((e) => e.code, 'code', AiErrorCode.cancelled),
      ),
    );
    expect(calls, 0);
    await expectLater(
      run(AiCancellationToken()),
      throwsA(
        isA<AiException>().having(
          (e) => e.message,
          'message',
          contains('could not shorten'),
        ),
      ),
    );
  });
}
