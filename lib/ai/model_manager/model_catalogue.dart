import '../providers/offline/offline_runtime.dart';
import '../hardware/ai_hardware.dart';

part 'model_catalogue_entries.dart';
part 'model_catalogue_csv.dart';
part 'model_catalogue_maid.dart';

const aiGiB = 1024 * 1024 * 1024;

/// An immutable, pinned artifact. Hash and byte length come from a trusted
/// publisher manifest, never from the download response itself.
class AiModelArtifact {
  AiModelArtifact({
    required this.url,
    required this.sha256,
    required this.bytes,
    required this.revision,
    Iterable<String> redirectHosts = const [],
  }) : redirectHosts = Set.unmodifiable(redirectHosts) {
    if (url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.fragment.isNotEmpty ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256) ||
        bytes < 4 ||
        revision.trim().isEmpty) {
      throw ArgumentError(
        'A pinned HTTPS artifact, SHA-256 and length are required.',
      );
    }
  }
  final Uri url;
  final String sha256;
  final int bytes;
  final String revision;

  /// Exact hosts permitted for HTTPS redirects. No wildcard matching.
  final Set<String> redirectHosts;
}

class AiCatalogueModel {
  AiCatalogueModel({
    required this.id,
    required this.name,
    required this.license,
    required this.source,
    required this.estimatedRamBytes,
    required this.estimatedDiskBytes,
    this.contextSize = 4096,
    this.quantization = 'Q4 (estimate)',
    Iterable<String> languages = const ['Multilingual; benchmark required'],
    this.vision = false,
    this.tools = false,
    this.artifact,
    Map<String, String> metadata = const {},
  }) : metadata = Map.unmodifiable(metadata),
       languages = List.unmodifiable(languages) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id) ||
        estimatedRamBytes < 1 ||
        estimatedDiskBytes < 4 ||
        contextSize < 1) {
      throw ArgumentError('Invalid model catalogue entry.');
    }
  }
  final String id, name, license, quantization;
  final Uri source;
  final int estimatedRamBytes, estimatedDiskBytes, contextSize;
  final List<String> languages;

  /// Capabilities of this adapter configuration, not the entire model family.
  final bool vision, tools;
  final AiModelArtifact? artifact;
  final Map<String, String> metadata;
  String get family => metadata['family'] ?? name.split(' ').first;
  double? get parameters => double.tryParse(metadata['parameters'] ?? '');

  /// First public family launch; YYYY-MM preserves publisher month precision.
  /// Month-only dates sort at the start of that month without claiming a day.
  DateTime? get familyReleaseDate {
    final value = metadata['familyReleaseDate'];
    if (value == null) return null;
    return DateTime.tryParse(value.length == 7 ? '$value-01' : value);
  }

  String? get repository => metadata['repository'];
  String? get filename => metadata['filename'];
  Uri? get downloadUrl {
    if (artifact != null) return artifact!.url;
    if (repository == null || filename == null) return null;
    return Uri.https(
      'huggingface.co',
      '/$repository/resolve/${metadata['revision'] ?? 'main'}/$filename',
    );
  }

  bool get downloadable =>
      artifact != null || (repository != null && filename != null);
  int recommendedRam(bool mobile) =>
      ((double.tryParse(metadata[mobile ? 'mobileRam' : 'desktopRam'] ?? '') ??
                  estimatedRamBytes / aiGiB) *
              aiGiB)
          .ceil();
}

class AiModelCatalogue {
  AiModelCatalogue(Iterable<AiCatalogueModel> entries)
    : models = List.unmodifiable(entries) {
    if (models.map((m) => m.id).toSet().length != models.length) {
      throw ArgumentError('Duplicate catalogue model IDs.');
    }
  }
  final List<AiCatalogueModel> models;

  static bool isLegacyEntry(AiCatalogueModel entry) => _pinnedModels().any(
    (p) =>
        p.id == entry.id &&
        p.source == entry.source &&
        p.name == entry.name &&
        p.license == entry.license &&
        p.quantization == entry.quantization &&
        p.contextSize == entry.contextSize &&
        p.estimatedRamBytes == entry.estimatedRamBytes &&
        p.estimatedDiskBytes == entry.estimatedDiskBytes &&
        p.languages.join(';') == entry.languages.join(';') &&
        p.artifact?.url == entry.artifact?.url &&
        p.artifact?.revision == entry.artifact?.revision &&
        p.artifact?.bytes == entry.artifact?.bytes &&
        p.artifact?.sha256 == entry.artifact?.sha256,
  );

  /// CSV catalogue. Missing pins are resolved from publisher metadata at download time.
  /// Hardware suitability is advisory; actual loading verifies compatibility.
  factory AiModelCatalogue.candidates() => AiModelCatalogue(_downloadModels());
}

enum AiModelFit {
  lightweight,
  smooth,
  balanced,
  heavy,
  veryHeavy,
  unknown,
  unsupported;

  // Source compatibility only. These are aliases, not extra enum values.
  // Old binary-fit assertions must migrate to the graded recommendation policy.
  @Deprecated('Use lightweight or smooth / fit.recommended instead.')
  static const AiModelFit candidate = smooth;

  @Deprecated('Use heavy, veryHeavy or unsupported as appropriate.')
  static const AiModelFit insufficient = veryHeavy;
}

extension AiModelFitLabel on AiModelFit {
  String get label => switch (this) {
    AiModelFit.lightweight => 'Lightweight',
    AiModelFit.smooth => 'Smooth',
    AiModelFit.balanced => 'Balanced',
    AiModelFit.heavy => 'Heavy',
    AiModelFit.veryHeavy => 'Very heavy',
    AiModelFit.unknown => 'Resources unknown',
    AiModelFit.unsupported => 'Unsupported runtime',
  };
  bool get recommended =>
      this == AiModelFit.lightweight || this == AiModelFit.smooth;
}

class AiModelRecommendation {
  AiModelRecommendation(
    this.model,
    this.fit,
    Iterable<String> reasons, {
    this.verified = false,
    this.memoryBytes,
  }) : reasons = List.unmodifiable(reasons);
  final AiCatalogueModel model;
  final AiModelFit fit;
  final List<String> reasons;
  final bool verified;
  final int? memoryBytes;
  String get label {
    final resources = switch (fit) {
      AiModelFit.lightweight => 'Low memory use',
      AiModelFit.smooth => 'Comfortable memory fit',
      AiModelFit.balanced => 'Moderate memory use',
      AiModelFit.heavy => 'High resource use',
      AiModelFit.veryHeavy => 'Very high resource use',
      _ => fit.label,
    };
    return '$resources · ${verified ? 'Ran on device' : 'Estimated; speed untested'}';
  }
}

/// Generic policy thresholds, not a model-specific compatibility table.
/// Pre-download estimates use artifact size; installed models use GGUF metadata.
class AiModelRecommender {
  const AiModelRecommender();

  List<AiModelRecommendation> recommend(
    AiHardwareReport hardware,
    AiModelCatalogue catalogue, {
    int? contextSize,
    Map<String, AiLocalModel> installed = const {},
  }) => List.unmodifiable(
    catalogue.models.map(
      (m) => classify(hardware, m, installed: installed[m.id]),
    ),
  );

  AiModelRecommendation classify(
    AiHardwareReport hardware,
    AiCatalogueModel model, {
    AiLocalModel? installed,
  }) {
    final reasons = <String>[];
    final performance = installed?.performance;
    final verified = performance != null;
    final bytes =
        installed?.estimatedMemoryBytes ??
        model.artifact?.bytes ??
        model.estimatedDiskBytes;
    // Before the file exists, use a generic overhead allowance. Never pretend
    // catalogued RAM, platform or mobile support flags are runtime facts.
    final estimate = installed?.estimatedMemoryBytes ?? bytes + bytes ~/ 4;
    final total = hardware.totalMemoryBytes;
    final available = hardware.availableMemoryBytes;
    final budget = total != null
        ? total * .75
        : available != null
        ? available * .75
        : null;
    final ratio = budget == null || budget <= 0 ? null : estimate / budget;
    var fit = ratio == null
        ? AiModelFit.unknown
        : ratio < .25
        ? AiModelFit.lightweight
        : ratio < .50
        ? AiModelFit.smooth
        : ratio < .75
        ? AiModelFit.balanced
        : ratio < .90
        ? AiModelFit.heavy
        : AiModelFit.veryHeavy;
    // A real success overrides speculative runtime incompatibility.
    if (!verified && hardware.runtimeSupported == false) {
      fit = AiModelFit.unsupported;
    }
    final speed =
        performance?.contextSize ==
            (installed?.activeContextSize ?? installed?.contextSize)
        ? performance?.tokensPerSecond
        : null;
    if (speed != null && speed.isFinite && speed > 0) {
      final speedFit = speed >= 15
          ? AiModelFit.smooth
          : speed >= 7
          ? AiModelFit.balanced
          : speed >= 3
          ? AiModelFit.heavy
          : AiModelFit.veryHeavy;
      if (fit == AiModelFit.unknown ||
          fit == AiModelFit.unsupported ||
          speedFit.index > fit.index) {
        fit = speedFit;
      }
      reasons.add(
        '${speed.toStringAsFixed(1)} tokens/s measured during ordinary inference (including prompt processing).',
      );
    }
    if (ratio != null) {
      reasons.add(
        'Estimated model memory is ${(ratio * 100).round()}% of the device memory budget.',
      );
    } else {
      reasons.add(
        'Device RAM counters are unavailable; try the model or refresh hardware.',
      );
    }
    if (available != null && available < estimate && !verified) {
      reasons.add(
        'Current free RAM is below the estimate; close other apps or use a smaller context.',
      );
    }
    final disk = hardware.freeStorageBytes;
    if (installed == null &&
        disk != null &&
        disk < (model.artifact?.bytes ?? model.estimatedDiskBytes)) {
      reasons.add('Reported free storage is below the download size.');
    }
    if (fit == AiModelFit.unsupported) {
      reasons.add('The current local runtime is unavailable on this platform.');
    }
    if (verified) {
      reasons.add(
        'Successfully generated on this device at ${performance.contextSize} context tokens; no manual benchmark is required.',
      );
    }
    return AiModelRecommendation(
      model,
      fit,
      reasons,
      verified: verified,
      memoryBytes: estimate,
    );
  }
}

List<AiCatalogueModel> _downloadModels() {
  final pins = _pinnedModels();
  final entries = _catalogueRows.map((r) {
    final pin = pins
        .where(
          (p) =>
              p.artifact?.url.pathSegments.last.toLowerCase() ==
              r[15].toLowerCase(),
        )
        .firstOrNull;
    return AiCatalogueModel(
      id: pin?.id ?? r[0].replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-'),
      name: r[1],
      license: r[5],
      source: Uri.parse(r[6]),
      estimatedRamBytes: (double.parse(r[8]) * aiGiB).ceil(),
      estimatedDiskBytes: (double.parse(r[7]) * 1000000).ceil(),
      contextSize: int.parse(r[13]),
      quantization: r[4],
      artifact: pin?.source.path == '/${r[14]}' ? pin?.artifact : null,
      metadata: Map.unmodifiable({
        'variant': r[0],
        'family': r[2],
        'parameters': r[3],
        'desktopRam': r[9],
        'mobileRam': r[10],
        'platforms': r[11],
        'mobileSupport': r[12],
        'repository': r[14],
        'filename': r[15],
        'revision': r[16],
        'evidence': r[17],
        'notes': r[18],
        'diskGiB': r[19],
        'familyReleaseDate': r[20],
        'familyReleaseSource': r[21],
      }),
    );
  }).toList();
  // Keep the existing default ID and installed profiles stable.
  final defaultIndex = entries.indexWhere((m) => m.id == 'gemma4-e4b');
  if (defaultIndex > 0) entries.insert(0, entries.removeAt(defaultIndex));
  return [...entries, ..._maidModels()];
}

/// Compact family groups, with newer generations first and small models first.
/// Mobile ordering uses sourced CSV family launch dates, with unknown dates last.
class AiModelFamily {
  AiModelFamily(this.name, this.models, this.recommendedId);
  final String name;
  final List<AiCatalogueModel> models;

  static bool isLegacyEntry(AiCatalogueModel entry) => _pinnedModels().any(
    (p) =>
        p.id == entry.id &&
        p.source == entry.source &&
        p.name == entry.name &&
        p.license == entry.license &&
        p.quantization == entry.quantization &&
        p.contextSize == entry.contextSize &&
        p.estimatedRamBytes == entry.estimatedRamBytes &&
        p.estimatedDiskBytes == entry.estimatedDiskBytes &&
        p.languages.join(';') == entry.languages.join(';') &&
        p.artifact?.url == entry.artifact?.url &&
        p.artifact?.revision == entry.artifact?.revision &&
        p.artifact?.bytes == entry.artifact?.bytes &&
        p.artifact?.sha256 == entry.artifact?.sha256,
  );

  /// Use the earliest known launch if custom rows supply mixed family dates.
  DateTime? get releaseDate => models
      .map((m) => m.familyReleaseDate)
      .whereType<DateTime>()
      .fold<DateTime?>(
        null,
        (date, next) => date == null || next.isBefore(date) ? next : date,
      );

  final String? recommendedId;

  static List<AiModelFamily> grouped(
    AiHardwareReport hardware,
    AiModelCatalogue catalogue, {
    Set<String> excluded = const {},
  }) {
    final fits = const AiModelRecommender().recommend(hardware, catalogue);
    final mobile = hardware.platform == 'android' || hardware.platform == 'ios';
    final groups = <String, List<AiCatalogueModel>>{};
    for (final fit in fits) {
      if (excluded.contains(fit.model.id)) {
        continue;
      }
      groups.putIfAbsent(fit.model.family, () => []).add(fit.model);
    }
    final byId = {for (final fit in fits) fit.model.id: fit};
    int sizeOf(AiCatalogueModel m) => m.artifact?.bytes ?? m.estimatedDiskBytes;

    final result = groups.entries.map((entry) {
      final models = entry.value
        ..sort((a, b) {
          final size = (a.parameters ?? 0).compareTo(b.parameters ?? 0);
          if (size != 0) return size;
          return sizeOf(a).compareTo(sizeOf(b));
        });
      // Unknown hardware never earns a recommendation badge.
      final candidates = models
          .where(
            (m) => fits.any((f) => f.model.id == m.id && f.fit.recommended),
          )
          .toList();
      candidates.sort((a, b) {
        final rank = byId[a.id]!.fit.index.compareTo(byId[b.id]!.fit.index);
        if (rank != 0) return rank;
        return mobile
            ? sizeOf(a).compareTo(sizeOf(b))
            : sizeOf(b).compareTo(sizeOf(a));
      });
      return AiModelFamily(entry.key, models, candidates.firstOrNull?.id);
    }).toList();
    result.sort((a, b) {
      if (!mobile) return a.name.compareTo(b.name);
      final aDate = a.releaseDate;
      final bDate = b.releaseDate;
      if (aDate == null && bDate != null) return 1;
      if (bDate == null && aDate != null) return -1;
      final dateOrder = aDate == null ? 0 : bDate!.compareTo(aDate);
      return dateOrder != 0 ? dateOrder : a.name.compareTo(b.name);
    });
    return result;
  }
}
