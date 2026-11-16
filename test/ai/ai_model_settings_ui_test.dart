import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/model_manager/native_models.dart';
import 'package:metersystem/ai/settings/ai_flutter_settings.dart';
import 'package:metersystem/ai/settings/ai_local_models_native.dart';

import 'ai_model_management_test.dart' show DownloadAdapter, FakeRuntime;

AiHardwareReport deviceHardware({bool supported = true}) => AiHardwareReport(
  platform: 'test',
  cpu: 'Test CPU',
  logicalCores: 8,
  availableMemoryBytes: 40 * aiGiB,
  totalMemoryBytes: 64 * aiGiB,
  freeStorageBytes: 100 * aiGiB,
  runtimeSupported: supported,
);

class UiModels extends AiLocalModels {
  @override
  get provider => null;
  @override
  AiHardwareReport? hardware;
  UiModels({bool supported = true}) {
    hardware = deviceHardware(supported: supported);
  }
  @override
  List<AiLocalInstallation> installed = [];
  @override
  bool busy = false;
  @override
  double? progress;
  @override
  String? loadedId;
  @override
  String? status;
  @override
  String? benchmark;
  @override
  bool get supported => hardware!.runtimeSupported!;
  Completer<void>? downloading;
  int downloads = 0, cancellations = 0;
  @override
  Future<void> refresh() async {
    notifyListeners();
  }

  @override
  Future<void> install(AiCatalogueModel model) async {
    downloads++;
    busy = true;
    progress = .5;
    notifyListeners();
    await downloading?.future;
    if (cancellations == 0) {
      installed = [
        AiLocalInstallation(
          id: model.id,
          name: model.name,
          bytes: model.artifact!.bytes,
          revision: model.artifact!.revision,
          sha256: model.artifact!.sha256,
        ),
      ];
    }
    busy = false;
    progress = null;
    notifyListeners();
  }

  @override
  Future<void> load(String id) async {
    loadedId = id;
    notifyListeners();
  }

  @override
  Future<void> unload() async {
    loadedId = null;
    notifyListeners();
  }

  @override
  Future<void> delete(String id) async {
    installed = [];
    loadedId = null;
    notifyListeners();
  }

  @override
  Future<void> measure(String id) async {
    benchmark = '20 tokens/s';
    notifyListeners();
  }

  @override
  void cancel() {
    cancellations++;
    downloading?.complete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AiSettingsStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    store = AiSettingsStore(preferences: await SharedPreferences.getInstance());
  });
  void largeView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1100, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test(
    'defaults roundtrip independently; all providers have populated choices',
    () async {
      final builtIn = store.loadDefaults();
      for (final kind in AiProviderKind.values) {
        expect(builtIn.forKind(kind).models, isNotEmpty);
      }
      final json = builtIn.toJson();
      (json['providers'] as List).first['models'] = ['custom-gguf'];
      await store.saveDefaults(AiDefaults.fromJson(json));
      expect(
        AiSettingsStore(preferences: store.preferences)
            .loadDefaults()
            .forKind(AiProviderKind.offline)
            .models,
        ['custom-gguf'],
      );
      expect(store.load().profiles, isEmpty);
      expect(store.load().allowOnlineProcessing, isFalse);
      expect(
        store.loadDefaults().catalogue.models.first.artifact!.sha256,
        AiModelCatalogue.candidates().models.first.artifact!.sha256,
      );
      final invalid = builtIn.toJson();
      (invalid['catalogue'] as List).first['artifact']['sha256'] = 'bad';
      expect(() => AiDefaults.fromJson(invalid), throwsArgumentError);
    },
  );

  testWidgets(
    'new profile has usable defaults and separate defaults screen persists edits',
    (tester) async {
      largeView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: AiSettingsScreen(
            store: store,
            localModels: () async => UiModels(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Local model manager'), findsOneWidget);
      expect(find.textContaining('Gemma 4 E4B'), findsOneWidget);
      expect(find.text('2048 tokens'), findsOneWidget);
      expect(find.text('4096 tokens'), findsOneWidget);
      await tester.tap(find.text('Provider and model defaults'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Model IDs (one per line; first is the default)',
        ),
        'new-default',
      );
      await tester.tap(find.text('Save defaults'));
      await tester.pumpAndSettle();
      expect(store.loadDefaults().forKind(AiProviderKind.offline).models, [
        'new-default',
      ]);
      expect(store.load().profiles, isEmpty);
    },
  );

  testWidgets(
    'model manager requires download consent and exposes lifecycle controls',
    (tester) async {
      largeView(tester);
      final models = UiModels();
      await tester.pumpWidget(
        MaterialApp(
          home: AiLocalModelsScreen(
            models: models,
            defaults: AiDefaults.builtIn(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Test CPU'), findsOneWidget);
      final downloads = tester
          .widgetList<FilledButton>(
            find.widgetWithText(FilledButton, 'Download'),
          )
          .toList();
      expect(downloads.where((b) => b.onPressed != null), hasLength(1));
      await tester.tap(find.text('Download').first);
      await tester.pumpAndSettle();
      expect(models.downloads, 0);
      expect(find.textContaining('SHA-256:'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(models.downloads, 0);
      await tester.tap(find.text('Download').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download and install'));
      await tester.pumpAndSettle();
      expect(models.downloads, 1);
      await tester.tap(find.text('Load'));
      await tester.pumpAndSettle();
      expect(models.loadedId, 'gemma4-e4b');
      await tester.tap(find.text('Benchmark'));
      await tester.pumpAndSettle();
      expect(find.text('20 tokens/s'), findsOneWidget);
      await tester.tap(find.text('Unload'));
      await tester.pumpAndSettle();
      expect(models.loadedId, isNull);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(models.installed, hasLength(1));
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(models.installed, isEmpty);
    },
  );

  testWidgets(
    'download progress can be cancelled and insufficient runtime blocks downloads',
    (tester) async {
      largeView(tester);
      final models = UiModels()..downloading = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: AiLocalModelsScreen(
            models: models,
            defaults: AiDefaults.builtIn(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download and install'));
      await tester.pump();
      expect(find.text('Downloading 50.0%'), findsOneWidget);
      await tester.tap(find.text('Cancel operation'));
      await tester.pumpAndSettle();
      expect(models.cancellations, 1);
      expect(models.installed, isEmpty);
      final unsupported = UiModels(supported: false);
      await tester.pumpWidget(
        MaterialApp(
          home: AiLocalModelsScreen(
            models: unsupported,
            defaults: AiDefaults.builtIn(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<FilledButton>(
              find.widgetWithText(FilledButton, 'Download'),
            )
            .every((b) => b.onPressed == null),
        isTrue,
      );
      expect(find.textContaining('unsupported on this device'), findsOneWidget);
    },
  );

  testWidgets(
    'installed model selection returns to settings and saves offline profile',
    (tester) async {
      largeView(tester);
      final models = UiModels();
      await models.install(AiModelCatalogue.candidates().models.first);
      await tester.pumpWidget(
        MaterialApp(
          home: AiSettingsScreen(store: store, localModels: () async => models),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Local model manager'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use model'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save settings'));
      await tester.tap(find.text('Save settings'));
      await tester.pumpAndSettle();
      expect(store.load().selectedProfile!.modelId, 'gemma4-e4b');
      expect(store.load().selectedProfile!.kind, AiProviderKind.offline);
      expect(store.load().settings.maxOutputTokens, 2048);
      expect(store.load().allowOnlineProcessing, isFalse);
    },
  );

  test('native UI session installs, restores, loads, benchmarks and deletes through real manager', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dayark-settings-models',
    );
    final adapter = DownloadAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final provider = OfflineAiProvider(models: [], runtime: FakeRuntime());
    final manager = AiLocalModelManager(
      directory: directory,
      provider: provider,
      dio: dio,
    );
    final models = NativeAiLocalModels(
      manager,
      hardwareProbe: ({required storagePath}) async => deviceHardware(),
    );
    addTearDown(() async {
      manager.close();
      dio.close();
      await provider.dispose();
      await directory.delete(recursive: true);
    });
    final entry = AiCatalogueModel(
      id: 'fixture',
      name: 'Fixture',
      license: 'test',
      source: Uri.parse('https://example.test/model'),
      estimatedRamBytes: aiGiB,
      estimatedDiskBytes: 1024,
      artifact: AiModelArtifact(
        url: Uri.parse('https://example.test/model.gguf'),
        sha256: sha256.convert(adapter.body).toString(),
        bytes: adapter.body.length,
        revision: 'test',
      ),
    );
    await models.refresh();
    await models.install(entry);
    expect(models.installed.single.id, 'fixture');
    expect(models.busy, isFalse);
    await models.refresh();
    expect(models.installed.single.id, 'fixture');
    await models.load('fixture');
    expect(models.loadedId, 'fixture');
    await models.measure('fixture');
    expect(models.benchmark, contains('tokens/s'));
    await models.unload();
    expect(models.loadedId, isNull);
    await models.delete('fixture');
    expect(models.installed, isEmpty);
    expect(await directory.list().toList(), isEmpty);
    adapter.body = utf8.encode('corrupt');
    await models.install(entry);
    expect(models.status, contains('installation failed'));
    expect(models.installed, isEmpty);
  });
}
