import '../hardware/ai_hardware.dart';

part 'model_catalogue_entries.dart';

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

  /// Pinned, single-file GGUF text models supported by the embedded adapter.
  /// Hardware suitability is advisory; actual loading verifies compatibility.
  factory AiModelCatalogue.candidates() => AiModelCatalogue(_downloadModels());
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
          '${model.quantization}; RAM estimates do not assume GPU savings.',
        );
        if (insufficient) {
          reasons.add(
            'You can still download and try this model. It may run slowly or fail to load.',
          );
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
