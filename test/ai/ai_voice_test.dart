import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/ai/voice/speech_provider.dart';
import 'package:metersystem/ai/voice/speech_models.dart';

void main() {
  test(
    'online permission blocks audio and credential access before IO',
    () async {
      var read = false;
      final provider = OnlineSpeechProvider(
        baseUrl: Uri.parse('https://api.openai.com/v1'),
        model: 'whisper-1',
        allowOnline: false,
        credential: () async {
          read = true;
          return 'secret';
        },
      );
      addTearDown(() => provider.client.close());
      await expectLater(provider.transcribe('/nonexistent'), throwsStateError);
      expect(read, isFalse);
    },
  );
  test(
    'Whisper reports missing model without allocating native memory',
    () async {
      await expectLater(
        const WhisperSpeechProvider('/nonexistent').transcribe('/none'),
        throwsStateError,
      );
    },
  );
  test('incomplete manifest cannot replace installed model', () async {
    final root = await Directory.systemTemp.createTemp('speech-test');
    addTearDown(() => root.delete(recursive: true));
    final models = SpeechModels(root);
    await expectLater(models.install({}), throwsArgumentError);
    expect(await models.installed, isFalse);
  });
  if (const bool.fromEnvironment('DAYARK_AI_SIMULATION')) {
    test(
      'multipart transcription and errors over Postman HTTP simulation',
      () async {
        final root = await Directory.systemTemp.createTemp('speech-http');
        addTearDown(() => root.delete(recursive: true));
        final wave = File('${root.path}/voice.wav');
        await wave.writeAsBytes([82, 73, 70, 70, 0, 0, 0, 0, 87, 65, 86, 69]);
        for (final scenario in ['', 'failure/', 'malformed/']) {
          final provider = OnlineSpeechProvider(
            baseUrl: Uri.parse('http://127.0.0.1:4018/speech/${scenario}v1'),
            model: 'whisper-1',
            allowOnline: true,
            credential: () async => 'synthetic-speech-key',
          );
          addTearDown(() => provider.client.close());
          if (scenario.isEmpty) {
            expect(
              (await provider.transcribe(wave.path, language: 'ur')).text,
              'Hello — اردو آواز',
            );
          } else {
            await expectLater(provider.transcribe(wave.path), throwsStateError);
          }
        }
      },
    );
  }
}
