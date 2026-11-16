import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../core/ai_cancellation.dart';
import '../core/ai_error.dart';
import '../providers/offline/offline_provider.dart';
import '../providers/offline/offline_runtime.dart';
import 'model_catalogue.dart';

typedef AiDownloadProgress = void Function(int received, int total);

class AiInstalledModel {
  const AiInstalledModel({
    required this.model,
    required this.revision,
    required this.sha256,
    required this.bytes,
  });
  final AiLocalModel model;
  final String revision, sha256;
  final int bytes;
}

/// Explicitly invoked native-only model store. No startup work or automatic
/// network requests. Each install requires user-authorized network access.
/// One owner per dedicated directory; atomic manifests survive process restarts.
class AiLocalModelManager {
  AiLocalModelManager({
    required this.directory,
    required this.provider,
    Dio? dio,
  }) : _dio =
           dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 30))),
       _ownsDio = dio == null;
  final Directory directory;
  final OfflineAiProvider provider;
  final Dio _dio;
  final bool _ownsDio;
  bool _busy = false;
  bool _closed = false;

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_closed || _busy) {
      throw const AiException(
        AiErrorCode.providerUnavailable,
        'Model store is closed or busy.',
      );
    }
    _busy = true;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }

  void _validateId(String id) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw ArgumentError('Invalid model ID.');
    }
  }

  File _manifest(String id) {
    _validateId(id);
    return File(p.join(directory.path, '$id.json'));
  }

  Future<void> _verify(
    File file,
    String hash,
    int bytes,
    AiCancellationToken token,
  ) async {
    token.throwIfCancelled();
    if (await file.length() != bytes) {
      throw const FormatException('Model length mismatch.');
    }
    final header = await file.open();
    try {
      if (utf8.decode(await header.read(4), allowMalformed: true) != 'GGUF') {
        throw const FormatException('Not a GGUF model.');
      }
    } finally {
      await header.close();
    }
    final digest = await sha256
        .bind(
          file.openRead().map((chunk) {
            token.throwIfCancelled();
            return chunk;
          }),
        )
        .first;
    if (digest.toString() != hash.toLowerCase()) {
      throw const FormatException('Model SHA-256 mismatch.');
    }
    token.throwIfCancelled();
  }

  Future<AiInstalledModel?> _read(
    String id,
    AiCancellationToken token, {
    bool verifyContents = true,
  }) async {
    final manifest = _manifest(id);
    if (!await manifest.exists()) return null;
    final data =
        jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    final hash = data['sha256'] as String;
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const FormatException('Invalid stored hash.');
    }
    final file = File(p.join(directory.path, '$id-$hash.gguf'));
    // Never trust paths from a writable manifest.
    if (verifyContents &&
        await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file) {
      throw const FormatException('Model is missing or is a symbolic link.');
    }
    if (verifyContents) await _verify(file, hash, data['bytes'] as int, token);
    return AiInstalledModel(
      model: AiLocalModel(
        id: id,
        path: file.path,
        name: data['name'] as String,
        contextSize: data['contextSize'] as int,
      ),
      revision: data['revision'] as String,
      sha256: hash,
      bytes: data['bytes'] as int,
    );
  }

  Future<ResponseBody> _download(
    AiModelArtifact artifact,
    CancelToken cancel,
  ) async {
    var url = artifact.url;
    for (var redirects = 0; redirects <= 5; redirects++) {
      final response = await _dio.get<ResponseBody>(
        url.toString(),
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          receiveTimeout: const Duration(minutes: 2),
          sendTimeout: const Duration(seconds: 30),
          validateStatus: (status) =>
              status == 200 || [301, 302, 303, 307, 308].contains(status),
        ),
        cancelToken: cancel,
      );
      final body = response.data!;
      if (response.statusCode == 200) return body;
      // Cancel the redirect body instead of buffering an unbounded error body.
      await body.stream.listen(null).cancel();
      final location = response.headers.value('location');
      if (location == null) {
        throw const FormatException('Redirect lacks location.');
      }
      final next = url.resolve(location);
      if (next.scheme != 'https' ||
          next.userInfo.isNotEmpty ||
          next.fragment.isNotEmpty ||
          !artifact.redirectHosts.contains(next.host)) {
        throw const FormatException('Unapproved model download redirect.');
      }
      url = next;
    }
    throw const FormatException('Too many download redirects.');
  }

  /// Revalidates installed files before registering them with the shared provider.
  Future<List<AiInstalledModel>> restore({
    AiCancellationToken? cancellationToken,
  }) => _exclusive(() async {
    final token = cancellationToken ?? AiCancellationToken();
    await directory.create(recursive: true);
    final installed = <AiInstalledModel>[];
    await for (final entity in directory.list(followLinks: false)) {
      token.throwIfCancelled();
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final id = p.basenameWithoutExtension(entity.path);
      final record = await _read(id, token);
      if (record != null) {
        await provider.maintainModel(
          id,
          () async => record.model,
          cancellationToken: token,
        );
        installed.add(record);
      }
    }
    return List.unmodifiable(installed);
  });

  /// Content-addressed file + atomic manifest commit keeps an old revision usable
  /// if a download, verification, cancellation or replacement fails.
  Future<AiInstalledModel> install(
    AiCatalogueModel entry, {
    required bool allowDownload,
    AiCancellationToken? cancellationToken,
    AiDownloadProgress? onProgress,
  }) => _exclusive(() async {
    final token = cancellationToken ?? AiCancellationToken();
    token.throwIfCancelled();
    if (!allowDownload) {
      throw const AiException(
        AiErrorCode.invalidRequest,
        'Model download requires authorization.',
      );
    }
    final artifact = entry.artifact;
    if (artifact == null) {
      throw ArgumentError('A verified publisher artifact is required.');
    }
    _validateId(entry.id);
    await directory.create(recursive: true);
    final hash = artifact.sha256.toLowerCase();
    final target = File(p.join(directory.path, '${entry.id}-$hash.gguf'));
    final staging = File('${target.path}.part');
    final manifest = _manifest(entry.id);
    final temporaryManifest = File('${manifest.path}.part');
    final old = await _read(entry.id, token, verifyContents: false);
    final cancel = CancelToken();
    final remove = token.onCancel(() => cancel.cancel());
    var committed = false;
    try {
      final response = await _download(artifact, cancel);
      final sink = staging.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          token.throwIfCancelled();
          received += chunk.length;
          if (received > artifact.bytes) {
            cancel.cancel();
            throw const FormatException('Download exceeds declared size.');
          }
          sink.add(chunk);
          // Bound queued data for multi-gigabyte artifacts.
          await sink.flush();
          onProgress?.call(received, artifact.bytes);
        }
      } finally {
        await sink.close();
      }
      await _verify(staging, hash, artifact.bytes, token);
      final record = AiInstalledModel(
        model: AiLocalModel(
          id: entry.id,
          name: entry.name,
          path: target.path,
          contextSize: entry.contextSize,
        ),
        revision: artifact.revision,
        sha256: hash,
        bytes: artifact.bytes,
      );
      await temporaryManifest.writeAsString(
        jsonEncode({
          'name': entry.name,
          'contextSize': entry.contextSize,
          'sha256': hash,
          'bytes': artifact.bytes,
          'revision': artifact.revision,
        }),
        flush: true,
      );
      token.throwIfCancelled();
      await provider.maintainModel(entry.id, () async {
        token.throwIfCancelled();
        if (await target.exists()) {
          await _verify(target, hash, artifact.bytes, token);
          await staging.delete();
        } else {
          await staging.rename(target.path);
        }
        // The manifest is the commit point. Do not honour cancellation between
        // the file commit and provider registration.
        await temporaryManifest.rename(manifest.path);
        committed = true;
        return record.model;
      }, cancellationToken: token);
      if (old != null && old.model.path != target.path) {
        try {
          await File(old.model.path).delete();
        } catch (_) {
          /* Orphan is harmless. */
        }
      }
      return record;
    } on AiException {
      rethrow;
    } catch (_) {
      token.throwIfCancelled();
      throw const AiException(
        AiErrorCode.providerUnavailable,
        'Model installation failed. Check network, storage and publisher integrity metadata.',
      );
    } finally {
      remove();
      for (final file in [staging, temporaryManifest]) {
        if (await file.exists()) await file.delete();
      }
      if (!committed &&
          old?.model.path != target.path &&
          await target.exists()) {
        await target.delete();
      }
    }
  });

  Future<void> delete(
    String id, {
    AiCancellationToken? cancellationToken,
  }) => _exclusive(() async {
    final token = cancellationToken ?? AiCancellationToken();
    final record = await _read(id, token, verifyContents: false);
    if (record == null) return;
    await provider.maintainModel(id, () async {
      token.throwIfCancelled();
      // Remove discovery first; interrupted cleanup leaves only an orphan file.
      await _manifest(id).delete();
      try {
        await File(record.model.path).delete();
      } catch (_) {
        /* Retry orphan cleanup externally. */
      }
      return null;
    }, cancellationToken: token);
  });

  Future<void> load(String id, {AiCancellationToken? cancellationToken}) =>
      _exclusive(() async {
        final token = cancellationToken ?? AiCancellationToken();
        final record = await _read(id, token);
        if (record == null) throw ArgumentError('Model is not installed.');
        await provider.maintainModel(
          id,
          () async => record.model,
          cancellationToken: token,
        );
        await provider.loadModel(id, cancellationToken: token);
      });
  Future<void> unload() => _exclusive(() => provider.unloadModel());
  void close() {
    if (_busy) throw StateError('Wait for the model operation before closing.');
    _closed = true;
    if (_ownsDio) _dio.close();
  }
}
