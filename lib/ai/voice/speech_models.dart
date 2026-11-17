import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Installs a user-selected multilingual sherpa Whisper bundle. Each asset must
/// have a trusted SHA-256; staging prevents partial installs becoming selectable.
class SpeechModels {
  SpeechModels(this.directory);
  final Directory directory;
  Future<bool> get installed async {
    for (final name in ['encoder.onnx', 'decoder.onnx', 'tokens.txt']) {
      if (!await File('${directory.path}/$name').exists()) return false;
    }
    return true;
  }

  Future<void> install(
    Map<String, ({Uri url, String sha256})> assets, {
    CancelToken? cancellation,
  }) async {
    if (assets.length != 3 ||
        ![
          'encoder.onnx',
          'decoder.onnx',
          'tokens.txt',
        ].every(assets.containsKey)) {
      throw ArgumentError('Encoder, decoder and tokens are required.');
    }
    final staging = Directory('${directory.path}.staging');
    await staging.create(recursive: true);
    final dio = Dio(BaseOptions(followRedirects: true));
    try {
      for (final entry in assets.entries) {
        final asset = entry.value;
        if (asset.url.scheme != 'https' ||
            !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(asset.sha256)) {
          throw ArgumentError('HTTPS URLs and SHA-256 checksums are required.');
        }
        final file = File('${staging.path}/${entry.key}');
        await dio.download(
          asset.url.toString(),
          file.path,
          cancelToken: cancellation,
        );
        final digest = await sha256.bind(file.openRead()).first;
        if (digest.toString() != asset.sha256.toLowerCase()) {
          throw StateError('Model checksum mismatch.');
        }
      }
      if (await directory.exists()) await directory.delete(recursive: true);
      await staging.rename(directory.path);
    } finally {
      dio.close();
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  Future<void> delete() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
