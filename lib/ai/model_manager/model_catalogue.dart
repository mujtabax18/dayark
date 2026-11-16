import '../hardware/ai_hardware.dart';

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
  }) : languages = List.unmodifiable(languages) {
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
}

class AiModelCatalogue {
  AiModelCatalogue(Iterable<AiCatalogueModel> entries)
    : models = List.unmodifiable(entries) {
    if (models.map((m) => m.id).toSet().length != models.length) {
      throw ArgumentError('Duplicate catalogue model IDs.');
    }
  }
  final List<AiCatalogueModel> models;

  /// Planning candidates, not validated runtime promises. E4B has a pinned
  /// publisher artifact; other entries require verified download metadata.
  factory AiModelCatalogue.candidates() => AiModelCatalogue([
    for (final spec in [
      ('gemma4-e4b', 'Gemma 4 E4B', 8, 6, 'gemma-4-E4B'),
      ('gemma4-12b', 'Gemma 4 12B', 12, 9, 'gemma-4-12B'),
      ('gemma4-26b', 'Gemma 4 26B A4B', 24, 18, 'gemma-4-26B-A4B'),
      ('gemma4-31b', 'Gemma 4 31B', 28, 22, 'gemma-4-31B'),
    ])
      AiCatalogueModel(
        id: spec.$1,
        name: spec.$2,
        license: 'Gemma terms; review publisher license before download',
        source: Uri.https('huggingface.co', '/google/${spec.$5}'),
        estimatedRamBytes: spec.$3 * aiGiB,
        estimatedDiskBytes: spec.$4 * aiGiB,
        artifact: spec.$1 == 'gemma4-e4b'
            ? AiModelArtifact(
                url: Uri.parse(
                  'https://huggingface.co/ggml-org/gemma-4-E4B-it-GGUF/resolve/1288d42c1f05addc1e3d947f29c8a5669c25182f/gemma-4-E4B-it-Q4_0.gguf',
                ),
                sha256: 'a555b900214b477d8880e7832e0b8925e139b0159640036b09fe472b6f2097f2',
                bytes: 4590807392,
                revision: '1288d42c1f05addc1e3d947f29c8a5669c25182f',
                redirectHosts: ['huggingface.co', 'cas-bridge.xethub.hf.co'],
              )
            : null,
      ),
  ]);
}

enum AiModelFit { candidate, insufficient, unknown }

class AiModelRecommendation {
  AiModelRecommendation(this.model, this.fit, Iterable<String> reasons)
    : reasons = List.unmodifiable(reasons);
  final AiCatalogueModel model;
  final AiModelFit fit;
  final List<String> reasons;
}

class AiModelRecommender {
  const AiModelRecommender({
    this.memoryReserveBytes = 2 * aiGiB,
    this.diskReserveBytes = aiGiB,
  });
  final int memoryReserveBytes, diskReserveBytes;

  List<AiModelRecommendation> recommend(
    AiHardwareReport hardware,
    AiModelCatalogue catalogue, {
    int contextSize = 4096,
  }) {
    if (contextSize < 1 || memoryReserveBytes < 0 || diskReserveBytes < 0) {
      throw ArgumentError('Context and reserve values are invalid.');
    }
    return List.unmodifiable(
      catalogue.models.map((model) {
        final reasons = <String>[];
        var insufficient = hardware.runtimeSupported == false;
        var unknown = hardware.runtimeSupported == null;
        if (insufficient) {
          reasons.add('Current embedded runtime is unsupported.');
        }
        if (unknown) {
          reasons.add('Native runtime compatibility requires a load test.');
        }
        // Never invent KV-cache scaling for an unmeasured context configuration.
        if (contextSize != model.contextSize) {
          unknown = true;
          reasons.add(
            'Memory estimate applies only at ${model.contextSize} context tokens.',
          );
        }
        final ram = hardware.availableMemoryBytes;
        final disk = hardware.freeStorageBytes;
        if (ram == null || disk == null) {
          unknown = true;
          reasons.add('RAM or destination storage is unknown.');
        }
        if (ram != null && ram < model.estimatedRamBytes + memoryReserveBytes) {
          insufficient = true;
          reasons.add('Insufficient available RAM including reserve.');
        }
        final requiredDisk = model.artifact?.bytes ?? model.estimatedDiskBytes;
        if (disk != null && disk < requiredDisk + diskReserveBytes) {
          insufficient = true;
          reasons.add('Insufficient free storage including reserve.');
        }
        reasons.add(
          'CPU-only ${model.quantization}; estimates require measured validation.',
        );
        if (insufficient) {
          reasons.add('Use an online API or self-hosted endpoint.');
        }
        return AiModelRecommendation(
          model,
          insufficient
              ? AiModelFit.insufficient
              : unknown
              ? AiModelFit.unknown
              : AiModelFit.candidate,
          reasons,
        );
      }),
    );
  }
}
