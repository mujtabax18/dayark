import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/ai/ai.dart';

class TestRuntime implements AiOfflineRuntime {
  final loaded = <String>[];
  final requests = <AiRequest>[];
  Completer<void>? loading;
  bool disposed = false;
  @override
  Future<void> load(AiLocalModel model, AiCancellationToken token) async {
    loaded.add(model.path);
    if (loading != null) await loading!.future;
    token.throwIfCancelled();
  }

  @override
  Future<AiResponse> generate(
    AiRequest request,
    AiCancellationToken token,
  ) async {
    requests.add(request);
    return AiResponse(
      selection: request.selection,
      message: AiMessage(role: AiRole.assistant, text: 'Offline reply'),
    );
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  late TestRuntime runtime;
  late OfflineAiProvider provider;
  late AiGateway gateway;
  setUp(() {
    runtime = TestRuntime();
    provider = OfflineAiProvider(
      models: [
        AiLocalModel(id: 'small', path: '/models/small.gguf'),
        AiLocalModel(id: 'other', path: '/models/other.gguf'),
      ],
      runtime: runtime,
    );
    gateway = AiGateway(providers: [provider]);
  });
  tearDown(() => provider.dispose());
  AiRequest request({String model = 'small', AiSettings? settings}) =>
      AiRequest(
        selection: AiModelSelection(providerId: 'offline', modelId: model),
        settings: settings,
        messages: [AiMessage(role: AiRole.user, text: 'Hello')],
      );
  Matcher fails(AiErrorCode code) =>
      throwsA(isA<AiException>().having((e) => e.code, 'code', code));

  test(
    'local models list without loading and connection test loads selected file',
    () async {
      final page = await gateway.listModels(providerId: 'offline');
      expect(page.models.map((m) => m.selection.modelId), ['small', 'other']);
      expect(runtime.loaded, isEmpty);
      expect(
        (await gateway.testConnection(
          providerId: 'offline',
          modelId: 'other',
        )).isConnected,
        true,
      );
      expect(runtime.loaded, ['/models/other.gguf']);
      expect(runtime.requests, isEmpty);
    },
  );
  test(
    'offline generation uses selected local model and same shared request',
    () async {
      final value = request();
      expect((await gateway.generate(value)).message.text, 'Offline reply');
      expect(runtime.requests.single, same(value));
      expect(runtime.loaded.single, '/models/small.gguf');
      await gateway.generate(request(model: 'other'));
      expect(runtime.loaded.last, '/models/other.gguf');
    },
  );
  test(
    'unknown models fail before loading and context ceilings reach the runtime',
    () async {
      await expectLater(
        gateway.generate(request(model: 'missing')),
        fails(AiErrorCode.providerUnavailable),
      );
      expect(runtime.loaded, isEmpty);
      await gateway.generate(
        request(settings: AiSettings(contextWindowTokens: 2048)),
      );
      expect(runtime.requests.single.settings.contextWindowTokens, 2048);
    },
  );
  test('concurrent native work is rejected and cancellation prevents inference after load', () async {
    runtime.loading = Completer<void>();
    final token = AiCancellationToken();
    final pending = gateway.generate(request(), cancellationToken: token);
    final check = expectLater(pending, fails(AiErrorCode.cancelled));
    await expectLater(
      gateway.generate(request()),
      fails(AiErrorCode.providerUnavailable),
    );
    token.cancel();
    await check;
    runtime.loading!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(runtime.requests, isEmpty);
    runtime.loading = null;
    await gateway.generate(request());
    expect(runtime.requests, hasLength(1));
  });
  test(
    'dispose cancels active load, waits, then releases runtime once',
    () async {
      runtime.loading = Completer<void>();
      final pending = gateway.generate(request());
      final check = expectLater(pending, fails(AiErrorCode.cancelled));
      final closing = provider.dispose();
      expect(runtime.disposed, false);
      runtime.loading!.complete();
      await closing;
      await check;
      expect(runtime.disposed, true);
      await expectLater(
        gateway.generate(request()),
        fails(AiErrorCode.providerUnavailable),
      );
    },
  );
  test(
    'idle timeout releases native runtime and clears loaded state',
    () async {
      provider.idleTimeout = const Duration(milliseconds: 10);
      await gateway.generate(request());
      expect(provider.loadedModelId, 'small');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(runtime.disposed, true);
      expect(provider.loadedModelId, isNull);
    },
  );
  test('remote paths and duplicate models are rejected', () {
    expect(
      () => AiLocalModel(id: 'remote', path: 'https://example.com/model.gguf'),
      throwsArgumentError,
    );
    expect(
      () => OfflineAiProvider(
        models: [
          AiLocalModel(id: 'same', path: '/a.gguf'),
          AiLocalModel(id: 'same', path: '/b.gguf'),
        ],
      ),
      throwsArgumentError,
    );
  });
}
