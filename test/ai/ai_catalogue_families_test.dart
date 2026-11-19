import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/settings/ai_defaults.dart';

void main() {
  AiHardwareReport device({
    String platform = 'android',
    int? available = 6 * aiGiB,
    int? total = 8 * aiGiB,
    bool? runtime = true,
  }) => AiHardwareReport(
    platform: platform,
    cpu: 'Fixture',
    logicalCores: 8,
    availableMemoryBytes: available,
    totalMemoryBytes: total,
    freeStorageBytes: 100 * aiGiB,
    runtimeSupported: runtime,
  );

  test('CSV variants retain family, quantization and hardware metadata', () {
    final catalogue = AiModelCatalogue.candidates();
    expect(catalogue.models, hasLength(337));
    expect(catalogue.models.map((m) => m.id).toSet(), hasLength(337));
    expect(
      catalogue.models.every(
        (m) =>
            m.downloadable &&
            m.parameters != null &&
            (m.metadata['evidence'] == 'publisher_manifest_not_device_tested' ||
                (m.familyReleaseDate != null &&
                    Uri.parse(m.metadata['familyReleaseSource']!).scheme ==
                        'https')),
      ),
      isTrue,
    );
    final restored = AiDefaults.fromJson(AiDefaults.builtIn().toJson());
    expect(
      restored.catalogue.models.first.metadata,
      catalogue.models.first.metadata,
    );
    expect(catalogue.models.any((m) => m.id == 'gemma4-e4b'), isTrue);
  });

  test('mobile generations are recent first and models are smallest first', () {
    final families = AiModelFamily.grouped(
      device(),
      AiModelCatalogue.candidates(),
    );
    expect(families.take(3).map((f) => f.name), [
      'Gemma 4',
      'Qwen3.5',
      'LFM2.5',
    ]);
    for (final family in families) {
      final sizes = family.models.map((m) => m.parameters!).toList();
      expect(sizes, orderedEquals([...sizes]..sort()));
      if (family.recommendedId == null) continue;
      final recommended = family.models
          .where((m) => m.id == family.recommendedId)
          .single;
      expect(
        recommended.quantization,
        anyOf('Q4', 'Q4_K_M', 'Q4_0', startsWith('Q2')),
      );
    }
  });

  test('family ordering uses catalogue dates, with ties alphabetical and unknown last', () {
    AiCatalogueModel entry(String id, String? date) => AiCatalogueModel(
      id: id,
      name: id,
      license: 'fixture',
      source: Uri.parse('https://example.test/$id'),
      estimatedRamBytes: aiGiB,
      estimatedDiskBytes: 1024,
      contextSize: 2048,
      metadata: {'family': id, 'familyReleaseDate': ?date},
    );
    final catalogue = AiModelCatalogue([
      entry('A-old', '2024-08'),
      entry('Z-new', '2026-02-16'),
      entry('B-new', '2026-02-16'),
      entry('C-undated', null),
    ]);
    final mobile = AiModelFamily.grouped(device(), catalogue);
    expect(mobile.map((f) => f.name), ['B-new', 'Z-new', 'A-old', 'C-undated']);
    expect(mobile[2].releaseDate, DateTime(2024, 8, 1));
    final desktop = AiModelFamily.grouped(device(platform: 'linux'), catalogue);
    expect(desktop.map((f) => f.name), [
      'A-old',
      'B-new',
      'C-undated',
      'Z-new',
    ]);
  });

  test('resource constrained mobile prefers Q2 when available', () {
    final families = AiModelFamily.grouped(
      device(available: 3 * aiGiB),
      AiModelCatalogue.candidates(),
    );
    final qwen = families.firstWhere((f) => f.name == 'Qwen3');
    expect(
      qwen.models.firstWhere((m) => m.id == qwen.recommendedId).quantization,
      'Q2_K',
    );
  });

  test('all variants stay visible on incompatible or unknown hardware without recommendation badges', () {
    final catalogue = AiModelCatalogue.candidates();
    for (final hardware in [
      device(platform: 'web'),
      device(runtime: false),
      device(available: aiGiB),
      device(total: aiGiB),
      device(available: null, total: null, runtime: null),
    ]) {
      final families = AiModelFamily.grouped(hardware, catalogue);
      expect(
        families.expand((f) => f.models).map((m) => m.id).toSet(),
        catalogue.models.map((m) => m.id).toSet(),
      );
      expect(families.every((f) => f.recommendedId == null), isTrue);
    }
    expect(
      catalogue.models.every((m) => m.downloadUrl?.scheme == 'https'),
      isTrue,
    );
  });
}
