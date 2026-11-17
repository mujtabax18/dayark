import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:llamadart/llamadart.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/providers/offline/llamadart_runtime.dart';

class RecordingEngine extends Fake implements LlamaEngine {
  final attempts = <ModelParams>[];
  int failures = 0;
  void Function()? onLoad;

  @override
  Future<void> setModel(
    LlamaModel model, {
    ModelParams params = const ModelParams(),
    ModelLoadOptions download = ModelLoadOptions.defaults,
    ModelDownloadProgressCallback? onProgress,
  }) async {
    attempts.add(params);
    onLoad?.call();
    if (failures-- > 0) throw StateError('GPU allocation failed');
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late Directory directory;
  late AiLocalModel model;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('dayark-gpu-test');
    final file = await File('${directory.path}/model.gguf')
        .writeAsString('GGUF');
    model = AiLocalModel(id: 'test', path: file.path, contextSize: 2048);
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'local loading requests partial offload and reuses loaded model',
    () async {
      final engine = RecordingEngine();
      final runtime = LlamadartRuntime(engine: engine);
      await runtime.load(model, AiCancellationToken());
      await runtime.load(model, AiCancellationToken());
      expect(engine.attempts, hasLength(1));
      expect(engine.attempts.single.device, ComputeDevice.auto);
      expect(engine.attempts.single.gpuLayers, inInclusiveRange(1, 8));
      expect(engine.attempts.single.contextSize, 2048);
      await runtime.dispose();
    },
  );

  test('GPU load failure retries on CPU with the same context', () async {
    final engine = RecordingEngine()..failures = 1;
    final runtime = LlamadartRuntime(engine: engine);
    await runtime.load(model, AiCancellationToken());
    expect(engine.attempts, hasLength(2));
    expect(engine.attempts.last.device, ComputeDevice.cpu);
    expect(engine.attempts.last.gpuLayers, 0);
    expect(engine.attempts.last.contextSize, 2048);
    await runtime.dispose();
  });

  test('cancelled GPU loading does not start a CPU retry', () async {
    final token = AiCancellationToken();
    final engine = RecordingEngine()
      ..failures = 1
      ..onLoad = token.cancel;
    final runtime = LlamadartRuntime(engine: engine);
    await expectLater(
      runtime.load(model, token),
      throwsA(
        isA<AiException>().having((e) => e.code, 'code', AiErrorCode.cancelled),
      ),
    );
    expect(engine.attempts, hasLength(1));
    await runtime.dispose();
  });

  test('GPU and CPU failure returns a model load error', () async {
    final engine = RecordingEngine()..failures = 2;
    final runtime = LlamadartRuntime(engine: engine);
    await expectLater(
      runtime.load(model, AiCancellationToken()),
      throwsA(
        isA<AiException>().having(
          (e) => e.code,
          'code',
          AiErrorCode.providerUnavailable,
        ),
      ),
    );
    expect(engine.attempts, hasLength(2));
    await runtime.dispose();
  });
}
