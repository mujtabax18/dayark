import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:llamadart/llamadart.dart';

abstract interface class EmbeddingProvider {
  String get modelId;
  Future<List<List<double>>> embed(List<String> texts);
}

/// Dedicated embedding GGUF; never reuses or replaces the selected chat model.
/// Identity is a SHA-256 supplied when selecting the file, not its mutable path.
class LocalEmbeddingProvider implements EmbeddingProvider {
  const LocalEmbeddingProvider({required this.path, required this.modelId});
  final String path;
  @override
  final String modelId;
  @override
  Future<List<List<double>>> embed(List<String> texts) async {
    if (!await File(path).exists()) {
      throw StateError('Embedding model is missing.');
    }
    if ((await sha256.bind(File(path).openRead()).first).toString() !=
        modelId) {
      throw StateError(
        'Embedding model changed. Select it again and rebuild the index.',
      );
    }
    final engine = LlamaEngine(LlamaBackend());
    try {
      await engine.setModel(
        LlamaModel(ModelSource.path(path)),
        params: const ModelParams(
          contextSize: 2048,
          gpuLayers: 0,
          device: ComputeDevice.cpu,
        ),
      );
      final vectors = <List<double>>[];
      for (final text in texts) {
        vectors.add(await engine.embed(text));
      }
      return vectors;
    } finally {
      await engine.dispose();
    }
  }
}
