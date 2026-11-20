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
  platform: 'linux',
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
  String? downloadingId;
  @override
  int get downloadedBytes => 512 * 1024 * 1024;
  @override
  int? get downloadTotalBytes => aiGiB;
  @override
  Future<void> refresh() async {
    notifyListeners();
  }

  @override
  Future<void> install(AiCatalogueModel model) async {
    downloads++;
    busy = true;
    downloadingId = model.id;
    progress = .5;
    notifyListeners();
    await downloading?.future;
    if (cancellations == 0) {
      installed = [
        AiLocalInstallation(
          id: model.id,
          name: model.name,
          bytes: model.artifact?.bytes ?? 1024,
          revision: model.artifact?.revision ?? 'test',
          sha256: model.artifact?.sha256 ?? 'a' * 64,
        ),
      ];
    }
    busy = false;
    downloadingId = null;
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
        store.loadDefaults().catalogue.models.first.metadata,
        AiModelCatalogue.candidates().models.first.metadata,
      );
      final invalid = builtIn.toJson();
      (invalid['catalogue'] as List).firstWhere(
        (m) => m['artifact'] != null,
      )['artifact']['sha256'] = 'bad';
      expect(() => AiDefaults.fromJson(invalid), throwsArgumentError);
    },
  );

  test('old planning catalogue upgrades and saved custom defaults stay intact', () async {
    final old = AiDefaults.builtIn().toJson()..remove('catalogueRevision');
    final entries = (old['catalogue'] as List).take(4).toList();
    for (final entry in entries) {
      entry['source'] =
          'https://huggingface.co/google/${['gemma-4-E4B', 'gemma-4-12B', 'gemma-4-26B-A4B', 'gemma-4-31B'][entries.indexOf(entry)]}';
      entry.remove('artifact');
    }
    final custom = Map<String, dynamic>.from(entries.first)
      ..['id'] = 'personal-model'
      ..['source'] = 'https://example.test/personal'
      ..['artifact'] = (AiDefaults.builtIn().toJson()['catalogue'] as List)
          .firstWhere((m) => m['artifact'] != null)['artifact'];
    old['catalogue'] = [...entries, custom];
    await store.preferences.setString(
      AiSettingsStore.defaultsKey,
      jsonEncode(old),
    );
    final upgraded = store.loadDefaults();
    expect(upgraded.catalogue.models.length, greaterThan(20));
    expect(upgraded.catalogue.models.every((m) => m.downloadable), isTrue);
    expect(upgraded.catalogue.models.last.id, 'personal-model');
    expect(upgraded.catalogue.models.last.source.host, 'example.test');
    final edited = upgraded.toJson();
    edited['catalogue'] = (edited['catalogue'] as List).take(1).toList();
    await store.saveDefaults(AiDefaults.fromJson(edited));
    expect(store.loadDefaults().catalogue.models, hasLength(1));
  });

  test('saved CSV catalogue gains dates without restoring deletions or replacing custom data', () async {
    final saved = AiDefaults.builtIn().toJson()..['catalogueRevision'] = 3;
    final entry = Map<String, dynamic>.from((saved['catalogue'] as List).first);
    final metadata = Map<String, dynamic>.from(entry['metadata'] as Map)
      ..remove('familyReleaseDate')
      ..remove('familyReleaseSource')
      ..['custom'] = 'retained';
    entry['metadata'] = metadata;
    final custom = {
      ...entry,
      'id': 'custom-release',
      'source': 'https://example.test/custom',
      'metadata': {...metadata, 'familyReleaseDate': '2024-06-10'},
    };
    saved['catalogue'] = [entry, custom];
    await store.preferences.setString(
      AiSettingsStore.defaultsKey,
      jsonEncode(saved),
    );
    final upgraded = store.loadDefaults();
    expect(upgraded.catalogue.models, hasLength(78));
    expect(
      upgraded.catalogue.models.first.metadata['familyReleaseDate'],
      '2026-04-02',
    );
    expect(upgraded.catalogue.models.first.metadata['custom'], 'retained');
    expect(
      upgraded.catalogue.models
          .singleWhere((m) => m.id == 'custom-release')
          .metadata['familyReleaseDate'],
      '2024-06-10',
    );
    expect(
      upgraded.catalogue.models
          .singleWhere((m) => m.id == 'custom-release')
          .metadata
          .containsKey('familyReleaseSource'),
      isFalse,
    );
  });

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
      expect(find.textContaining('gemma-4-E4B-it'), findsOneWidget);
      expect(find.text('Maximum output tokens'), findsOneWidget);
      expect(
        find.textContaining('Output limits include reasoning tokens'),
        findsOneWidget,
      );
      expect(find.text('Automatic context window'), findsOneWidget);
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
    'settings uses searchable model selection and persists its choice on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await store.save(
        AiPreferences(
          profiles: [
            AiProviderProfile(
              id: 'api',
              name: 'My API',
              kind: AiProviderKind.openai,
              modelId: 'old-model',
            ),
          ],
          selectedProfileId: 'api',
        ),
      );
      final defaults = store.loadDefaults().toJson();
      final providers = defaults['providers'] as List;
      final openai = providers.firstWhere((p) => p['kind'] == 'openai');
      openai['models'] = ['old-model', 'replacement-model'];
      await store.saveDefaults(AiDefaults.fromJson(defaults));
      await tester.pumpWidget(
        MaterialApp(home: AiSettingsScreen(store: store)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Model'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'old-model'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search models'),
        'replacement',
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('old-model'),
        ),
        findsNothing,
      );
      await tester.tap(find.text('replacement-model'));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save settings'));
      await tester.pumpAndSettle();
      expect(store.load().selectedProfile!.modelId, 'replacement-model');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact download controls require consent and expose lifecycle actions',
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
      expect(find.text('Downloaded models'), findsOneWidget);
      final download = find.byIcon(Icons.download_rounded).first;
      await tester.ensureVisible(download);
      await tester.tap(download);
      await tester.pumpAndSettle();
      expect(models.downloads, 0);
      expect(find.textContaining('SHA-256'), findsOneWidget);
      await tester.tap(find.text('Download and install'));
      await tester.pumpAndSettle();
      expect(models.downloads, 1);
      await tester.tap(find.byTooltip('Load model'));
      await tester.pumpAndSettle();
      expect(models.loadedId, models.installed.single.id);
      expect(find.text('Active'), findsOneWidget);
      await tester.tap(find.text('View More').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Benchmark'));
      await tester.tap(find.text('Benchmark'));
      await tester.pumpAndSettle();
      expect(find.text('20 tokens/s'), findsOneWidget);
      await tester.tap(find.text('Unload'));
      await tester.pumpAndSettle();
      expect(models.loadedId, isNull);
      Navigator.of(tester.element(find.text('20 tokens/s'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete model'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(models.installed, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'version dropdown shows sizes and downloads the selected variant on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final base = AiDefaults.builtIn();
      final variants = base.catalogue.models
          .where(
            (m) =>
                m.name == 'Qwen3.5-0.8B' &&
                ['Q4_K_M', 'Q8_0'].contains(m.quantization),
          )
          .toList();
      final models = UiModels();
      await tester.pumpWidget(
        MaterialApp(
          home: AiLocalModelsScreen(
            models: models,
            defaults: AiDefaults(
              providers: base.providers,
              catalogue: AiModelCatalogue(variants),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dropdown = find.byKey(const ValueKey('model-version-Qwen3.5-0.8B'));
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      expect(find.textContaining('MiB'), findsWidgets);
      await tester.tap(find.textContaining('Q8_0').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Download Q8_0'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download and install'));
      await tester.pumpAndSettle();
      expect(
        models.installed.single.id,
        variants.singleWhere((m) => m.quantization == 'Q8_0').id,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'download bytes and cancel survive leaving and reopening screen',
    (tester) async {
      final models = UiModels()..downloading = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiLocalModelsScreen(
                      models: models,
                      defaults: AiDefaults.builtIn(),
                    ),
                  ),
                ),
                child: const Text('Open models'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open models'));
      await tester.pumpAndSettle();
      final download = find.byIcon(Icons.download_rounded).first;
      await tester.ensureVisible(download);
      await tester.tap(download);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download and install'));
      await tester.pump();
      expect(find.textContaining('Downloading 50.0%'), findsOneWidget);
      expect(find.textContaining(' / '), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(models.busy, isTrue);
      await tester.tap(find.text('Open models'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Downloading 50.0%'), findsOneWidget);
      await tester.tap(find.byTooltip('Cancel operation'));
      await tester.pumpAndSettle();
      expect(models.cancellations, 1);
      expect(models.installed, isEmpty);
    },
  );

  testWidgets(
    'incompatible downloads remain enabled with warnings and user can proceed',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final models = UiModels()
        ..hardware = AiHardwareReport(
          platform: 'android',
          cpu: 'Mobile CPU',
          logicalCores: 4,
          availableMemoryBytes: aiGiB,
          freeStorageBytes: aiGiB,
          runtimeSupported: true,
        );
      await tester.pumpWidget(
        MaterialApp(
          home: AiLocalModelsScreen(
            models: models,
            defaults: AiDefaults.builtIn(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('337 available variants · recommendations are advisory'),
        findsOneWidget,
      );
      expect(find.textContaining('Not recommended:'), findsNothing);
      final download = find.byIcon(Icons.download_rounded).first;
      await tester.ensureVisible(download);
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(of: download, matching: find.byType(IconButton)),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(download);
      await tester.pumpAndSettle();
      expect(find.textContaining('Estimated model memory'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
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
      final unsupportedDownload = find.byIcon(Icons.download_rounded).first;
      await tester.ensureVisible(unsupportedDownload);
      await tester.tap(unsupportedDownload);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('local runtime is unavailable'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Download and install'));
      await tester.pumpAndSettle();
      expect(unsupported.downloads, 1);
      expect(unsupported.installed, hasLength(1));
      expect(tester.takeException(), isNull);
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
      await tester.tap(find.byTooltip('Use model'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send additional prompt'));
      await tester.tap(find.text('Send additional prompt'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save settings'));
      await tester.tap(find.text('Save settings'));
      await tester.pumpAndSettle();
      expect(store.load().settings.sendAdditionalPrompt, isFalse);
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
      hardwareProbe: ({required storagePath}) async =>
          deviceHardware(supported: false),
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
    final transfers = <(String?, int, int?)>[];
    models.addListener(() {
      if (models.downloadingId != null) {
        transfers.add((
          models.downloadingId,
          models.downloadedBytes,
          models.downloadTotalBytes,
        ));
      }
    });
    await models.install(entry);
    expect(transfers.first, ('fixture', 0, adapter.body.length));
    expect(transfers.last, (
      'fixture',
      adapter.body.length,
      adapter.body.length,
    ));
    expect(models.downloadingId, isNull);
    expect(models.downloadedBytes, 0);
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
