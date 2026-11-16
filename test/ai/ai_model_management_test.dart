import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/model_manager/native_models.dart';

class FakeRuntime implements AiOfflineRuntime {
  int loads = 0, disposals = 0;
  Completer<void>? loading;
  @override
  Future<void> load(AiLocalModel model, AiCancellationToken token) async {
    loads++;
    await loading?.future;
    token.throwIfCancelled();
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }

  @override
  Future<AiResponse> generate(
    AiRequest request,
    AiCancellationToken token,
  ) async => AiResponse(
    selection: request.selection,
    message: AiMessage(role: AiRole.assistant, text: 'Test response'),
    usage: const AiUsage(outputTokens: 12),
  );
}

class DownloadAdapter implements HttpClientAdapter {
  List<int> body = utf8.encode('GGUFsynthetic-model');
  int status = 200, calls = 0;
  RequestOptions? lastRequest;
  String? redirectTo;
  Completer<void>? delay;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    lastRequest = options;
    if (delay != null) await Future.any([delay!.future, cancelFuture!]);
    if (redirectTo != null && options.uri.host == 'example.test') {
      return ResponseBody.fromBytes(
        [],
        302,
        headers: {
          'location': [redirectTo!],
        },
      );
    }
    return ResponseBody.fromBytes(body, status);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  AiHardwareReport hardware({
    int? ram = 16 * aiGiB,
    int? disk = 40 * aiGiB,
    bool? supported = true,
  }) => AiHardwareReport(
    platform: 'test',
    cpu: 'test',
    logicalCores: 8,
    availableMemoryBytes: ram,
    freeStorageBytes: disk,
    runtimeSupported: supported,
  );

  test('candidate catalogue and conservative hardware recommendations', () {
    final catalogue = AiModelCatalogue.candidates();
    const engine = AiModelRecommender();
    final fits = engine.recommend(hardware(), catalogue);
    expect(fits.map((r) => r.fit), [
      AiModelFit.candidate,
      AiModelFit.candidate,
      AiModelFit.insufficient,
      AiModelFit.insufficient,
    ]);
    expect(
      engine.recommend(hardware(ram: null), catalogue).first.fit,
      AiModelFit.unknown,
    );
    expect(
      engine.recommend(hardware(supported: null), catalogue).first.fit,
      AiModelFit.unknown,
    );
    expect(
      engine
          .recommend(hardware(supported: false), catalogue)
          .every((r) => r.fit == AiModelFit.insufficient),
      true,
    );
    expect(
      engine.recommend(hardware(disk: 0), catalogue).first.fit,
      AiModelFit.insufficient,
    );
    expect(
      engine.recommend(hardware(), catalogue, contextSize: 8192).first.fit,
      AiModelFit.unknown,
    );
    expect(() => catalogue.models.clear(), throwsUnsupportedError);
    expect(
      () => AiModelArtifact(
        url: Uri.parse('http://example.test/m.gguf'),
        sha256: 'a' * 64,
        bytes: 4,
        revision: 'v1',
      ),
      throwsArgumentError,
    );
  });

  test('real HTTP streaming succeeds; redirects and server failures do not install', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dayark-http-model-',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var status = 200;
    var requests = 0;
    final body = utf8.encode('GGUFstreamed-model-fixture');
    final serving = server.listen((request) async {
      requests++;
      request.response.statusCode = status;
      if (status == 302) {
        request.response.headers.set('location', '/redirect-target');
      }
      request.response.add(body.sublist(0, 4));
      await request.response.flush();
      request.response.add(body.sublist(4));
      await request.response.close();
    });
    final provider = OfflineAiProvider(models: [], runtime: FakeRuntime());
    final dio = Dio();
    // Test-only transport routing: production artifacts remain HTTPS-only.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.path = 'http://127.0.0.1:${server.port}/model.gguf';
          handler.next(options);
        },
      ),
    );
    final store = AiLocalModelManager(
      directory: directory,
      provider: provider,
      dio: dio,
    );
    final model = AiCatalogueModel(
      id: 'http-test',
      name: 'HTTP test',
      license: 'fixture',
      source: Uri.https('example.test', '/'),
      estimatedRamBytes: 1024,
      estimatedDiskBytes: body.length,
      artifact: AiModelArtifact(
        url: Uri.https('example.test', '/model.gguf'),
        sha256: sha256.convert(body).toString(),
        bytes: body.length,
        revision: 'test',
      ),
    );
    try {
      final installed = await store.install(model, allowDownload: true);
      expect(await File(installed.model.path).readAsBytes(), body);
      for (final failure in [302, 500]) {
        status = failure;
        await expectLater(
          store.install(model, allowDownload: true),
          throwsA(isA<AiException>()),
        );
        expect((await store.restore()).single.sha256, installed.sha256);
      }
      expect(requests, 3); // A redirect must never produce a second request.
    } finally {
      store.close();
      dio.close();
      await provider.dispose();
      await serving.cancel();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });

  group('model store', () {
    late Directory directory;
    late FakeRuntime runtime;
    late OfflineAiProvider provider;
    late DownloadAdapter adapter;
    late Dio dio;
    late AiLocalModelManager store;
    AiCatalogueModel entry({
      String? hash,
      int? bytes,
      String revision = 'v1',
      Iterable<String> redirectHosts = const [],
    }) => AiCatalogueModel(
      id: 'test',
      name: 'Test GGUF',
      license: 'test fixture',
      source: Uri.https('example.test', '/model'),
      estimatedRamBytes: aiGiB,
      estimatedDiskBytes: 1024,
      artifact: AiModelArtifact(
        url: Uri.https('example.test', '/model.gguf'),
        sha256: hash ?? sha256.convert(adapter.body).toString(),
        bytes: bytes ?? adapter.body.length,
        revision: revision,
        redirectHosts: redirectHosts,
      ),
    );
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('dayark-model-test-');
      runtime = FakeRuntime();
      provider = OfflineAiProvider(models: [], runtime: runtime);
      adapter = DownloadAdapter();
      dio = Dio()..httpClientAdapter = adapter;
      store = AiLocalModelManager(
        directory: directory,
        provider: provider,
        dio: dio,
      );
    });
    tearDown(() async {
      store.close();
      dio.close();
      await provider.dispose();
      await directory.delete(recursive: true);
    });
    Future<List<String>> ids() async =>
        (await provider.listModels(cancellationToken: AiCancellationToken()))
            .models
            .map((m) => m.selection.modelId)
            .toList();

    test(
      'verified install, update, restart restore, load, unload and delete',
      () async {
        var received = 0;
        final first = await store.install(
          entry(),
          allowDownload: true,
          onProgress: (count, total) {
            received = count;
            expect(total, adapter.body.length);
          },
        );
        expect(received, adapter.body.length);
        expect(await ids(), ['test']);
        expect(await File(first.model.path).readAsBytes(), adapter.body);
        expect(adapter.lastRequest!.followRedirects, false);
        await store.load('test');
        expect(runtime.loads, 1);
        await store.unload();
        expect(runtime.disposals, greaterThan(0));
        adapter.body = utf8.encode('GGUFupdated-model');
        final second = await store.install(
          entry(revision: 'v2'),
          allowDownload: true,
        );
        expect(second.revision, 'v2');
        expect(await File(first.model.path).exists(), false);
        store.close();
        await provider.dispose();
        runtime = FakeRuntime();
        provider = OfflineAiProvider(models: [], runtime: runtime);
        store = AiLocalModelManager(
          directory: directory,
          provider: provider,
          dio: dio,
        );
        expect(await ids(), isEmpty);
        expect((await store.restore()).single.sha256, second.sha256);
        expect(await ids(), ['test']);
        await store.delete('test');
        expect(await ids(), isEmpty);
        expect(await directory.list().toList(), isEmpty);
      },
    );

    test(
      'only explicitly approved HTTPS redirect hosts are followed',
      () async {
        adapter.redirectTo =
            'https://cdn.example.test/model.gguf?signature=test';
        await store.install(
          entry(redirectHosts: ['cdn.example.test']),
          allowDownload: true,
        );
        expect(adapter.calls, 2);
        expect(adapter.lastRequest!.uri.host, 'cdn.example.test');
        adapter.redirectTo = 'http://cdn.example.test/model.gguf';
        await expectLater(
          store.install(
            entry(redirectHosts: ['cdn.example.test']),
            allowDownload: true,
          ),
          throwsA(isA<AiException>()),
        );
        adapter.redirectTo = 'https://unapproved.test/model.gguf';
        await expectLater(
          store.install(
            entry(redirectHosts: ['cdn.example.test']),
            allowDownload: true,
          ),
          throwsA(isA<AiException>()),
        );
      },
    );

    test('consent and missing metadata prevent network access', () async {
      await expectLater(
        store.install(entry(), allowDownload: false),
        throwsA(isA<AiException>()),
      );
      await expectLater(
        store.install(
          AiModelCatalogue.candidates().models.last,
          allowDownload: true,
        ),
        throwsArgumentError,
      );
      expect(adapter.calls, 0);
    });

    test(
      'bad hash, size, GGUF header and HTTP error never register files',
      () async {
        await expectLater(
          store.install(entry(hash: 'a' * 64), allowDownload: true),
          throwsA(isA<AiException>()),
        );
        await expectLater(
          store.install(entry(bytes: 4), allowDownload: true),
          throwsA(isA<AiException>()),
        );
        await expectLater(
          store.install(entry(bytes: 100), allowDownload: true),
          throwsA(isA<AiException>()),
        );
        adapter.body = utf8.encode('HTMLnot-a-model');
        await expectLater(
          store.install(entry(), allowDownload: true),
          throwsA(isA<AiException>()),
        );
        adapter.status = 500;
        await expectLater(
          store.install(entry(), allowDownload: true),
          throwsA(isA<AiException>()),
        );
        expect(await ids(), isEmpty);
        expect(await directory.list().toList(), isEmpty);
      },
    );

    test(
      'failed update preserves old manifest, model and registration',
      () async {
        final old = await store.install(entry(), allowDownload: true);
        adapter.body = utf8.encode('GGUFbad-update');
        await expectLater(
          store.install(entry(hash: 'b' * 64), allowDownload: true),
          throwsA(isA<AiException>()),
        );
        expect((await store.restore()).single.sha256, old.sha256);
        expect(await File(old.model.path).exists(), true);
        expect(await ids(), ['test']);
      },
    );

    test('cancellation cleans partial files and releases store', () async {
      final token = AiCancellationToken();
      await expectLater(
        store.install(
          entry(),
          allowDownload: true,
          cancellationToken: token,
          onProgress: (_, _) => token.cancel(),
        ),
        throwsA(
          isA<AiException>().having(
            (e) => e.code,
            'code',
            AiErrorCode.cancelled,
          ),
        ),
      );
      expect(await directory.list().toList(), isEmpty);
      await store.install(entry(), allowDownload: true);
      expect(await ids(), ['test']);
    });

    test('busy store and active inference protect files', () async {
      final first = await store.install(entry(), allowDownload: true);
      runtime.loading = Completer<void>();
      final loading = provider.loadModel('test');
      await expectLater(store.delete('test'), throwsA(isA<AiException>()));
      expect(await File(first.model.path).exists(), true);
      runtime.loading!.complete();
      await loading;
      runtime.loading = null;
      adapter.delay = Completer<void>();
      final token = AiCancellationToken();
      final installing = store.install(
        entry(),
        allowDownload: true,
        cancellationToken: token,
      );
      final cancelled = expectLater(installing, throwsA(isA<AiException>()));
      await expectLater(store.restore(), throwsA(isA<AiException>()));
      token.cancel();
      adapter.delay!.complete();
      await cancelled;
    });

    test('restore rejects tampering and unsafe model IDs', () async {
      final installed = await store.install(entry(), allowDownload: true);
      await File(installed.model.path).writeAsString('GGUFtampered');
      await expectLater(store.restore(), throwsFormatException);
      await store.delete('test');
      expect(await ids(), isEmpty);
      await expectLater(store.delete('../outside'), throwsArgumentError);
    });

    test(
      'benchmark reports measured token throughput and process RSS',
      () async {
        await store.install(entry(), allowDownload: true);
        final report = await benchmarkLocalModel(
          provider: provider,
          modelId: 'test',
          prompt: 'آج کے دن کی منصوبہ بندی کریں',
        );
        expect(report.outputTokens, 12);
        expect(report.rssBeforeBytes, greaterThan(0));
        expect(
          report.sampledPeakRssBytes,
          greaterThanOrEqualTo(report.rssBeforeBytes),
        );
        expect(report.outputTokensPerSecond, greaterThan(0));
      },
    );
  });
}
