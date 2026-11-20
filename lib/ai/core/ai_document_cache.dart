import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Session-only PDF text cache. Content hashes invalidate edited attachments;
/// bounded entries hold extracted text rather than copies of input documents.
class AiDocumentTextCache {
  final _entries = <String, String>{};
  int _characters = 0;
  static const maxCharacters = 1024 * 1024;
  static const maxEntries = 8;

  Future<String> extract(
    Uint8List bytes,
    Future<String> Function() extraction, {
    void Function()? checkCancellation,
  }) async {
    final result = _DigestSink();
    final hash = sha256.startChunkedConversion(result);
    // Yield between hashing slices so file preparation stays cancellable in UI.
    for (var offset = 0; offset < bytes.length; offset += 128 * 1024) {
      checkCancellation?.call();
      hash.add(
        Uint8List.sublistView(
          bytes,
          offset,
          (offset + 128 * 1024).clamp(0, bytes.length),
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }
    hash.close();
    final key = result.value.toString();
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached;
    }
    checkCancellation?.call();
    final text = await extraction();
    checkCancellation?.call();
    if (text.length > maxCharacters) return text;
    while (_entries.isNotEmpty &&
        (_entries.length >= maxEntries ||
            _characters + text.length > maxCharacters)) {
      _characters -= _entries.remove(_entries.keys.first)!.length;
    }
    _entries[key] = text;
    _characters += text.length;
    return text;
  }

  void clear() {
    _entries.clear();
    _characters = 0;
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}
