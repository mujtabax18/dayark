import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

/// Reads only the GGUF header and metadata; never maps tensor weights.
/// GGUF v2/v3 little endian. Unknown architecture fields remain unknown.
class GgufMetadata {
  const GgufMetadata(this.values, this.bytes);
  final Map<String, Object> values;
  final int bytes;
  String? get architecture => values['general.architecture'] as String?;
  int? get nativeContext => _positive('$architecture.context_length');
  int? get fileType => values['general.file_type'] as int?;
  int? get layerCount => _positive('$architecture.block_count');
  int? _positive(String key) {
    final value = values[key];
    return value is int && value > 0 ? value : null;
  }

  /// Approximation for conventional attention with F16 K/V. Hybrid/MLA and
  /// per-layer variations may differ; never treat this as an allocation guarantee.
  int? get kvBytesPerToken {
    final a = architecture;
    final layers = _positive('$a.block_count');
    final embedding = _positive('$a.embedding_length');
    final heads = _positive('$a.attention.head_count');
    if (layers == null || embedding == null || heads == null) return null;
    final kvHeads = _positive('$a.attention.head_count_kv') ?? heads;
    final key = _positive('$a.attention.key_length') ?? embedding ~/ heads;
    final value = _positive('$a.attention.value_length') ?? embedding ~/ heads;
    if (key <= 0 || value <= 0) return null;
    return 2 * layers * kvHeads * (key + value);
  }

  /// General safety policy, not a model-family context table. Use a share of
  /// measured RAM for KV cache and leave room for weights, OS and scratch buffers.
  int chooseContext(int? availableBytes, int? totalBytes) {
    final native = nativeContext;
    if (native == null) {
      throw const FormatException('GGUF does not declare a native context length.');
    }
    final available = availableBytes ?? (totalBytes == null ? null : totalBytes ~/ 2);
    final kv = kvBytesPerToken;
    final minimum = math.min(native, 256);
    if (available == null) return math.min(native, 1024);
    if (kv == null) {
      // Conservative fallback for architectures that do not expose scalar KV
      // dimensions. Prefer a usable context only when weight headroom permits.
      return math.min(native, available > bytes * 2 ? 1024 : minimum);
    }
    final budget = math.min(available ~/ 5, available * 3 ~/ 4 - bytes);
    final capacity = math.max(minimum, budget ~/ kv);
    final bounded = math.min(native, capacity);
    // Round down for common runtime alignment, without raising the model limit.
    return bounded < 256 ? bounded : bounded ~/ 256 * 256;
  }

  static Future<GgufMetadata> read(String path) => Isolate.run(() {
    final file = File(path).openSync();
    try {
      return _GgufReader(file).parse();
    } finally {
      file.closeSync();
    }
  });
}

class _GgufReader {
  _GgufReader(this.file) : length = file.lengthSync();
  final RandomAccessFile file;
  final int length;
  static const _sizes = <int, int>{0: 1, 1: 1, 2: 2, 3: 2, 4: 4, 5: 4, 6: 4, 7: 1, 10: 8, 11: 8, 12: 8};
  Uint8List _read(int n) {
    if (n < 0 || n > length - file.positionSync()) throw const FormatException('Truncated GGUF metadata.');
    final result = file.readSync(n);
    if (result.length != n) throw const FormatException('Truncated GGUF metadata.');
    return result;
  }
  void _skip(int n) {
    final p = file.positionSync();
    if (n < 0 || n > length - p) throw const FormatException('Invalid GGUF metadata length.');
    file.setPositionSync(p + n);
  }
  int _u32() => ByteData.sublistView(_read(4)).getUint32(0, Endian.little);
  int _u64() {
    final n = ByteData.sublistView(_read(8)).getUint64(0, Endian.little);
    if (n < 0) throw const FormatException('GGUF metadata length overflow.');
    return n;
  }
  String _string() {
    final n = _u64();
    if (n > 1024 * 1024) throw const FormatException('GGUF metadata text is too large.');
    return utf8.decode(_read(n));
  }
  void _skipValue(int type) {
    if (_sizes[type] case final size?) { _skip(size); return; }
    if (type == 8) { _skip(_u64()); return; }
    if (type == 9) {
      final item = _u32();
      final count = _u64();
      if (count > length - file.positionSync()) throw const FormatException('Invalid GGUF array.');
      if (_sizes[item] case final width?) { _skip(count * width); return; }
      if (item != 8) throw const FormatException('Unsupported GGUF array type.');
      for (var i = 0; i < count; i++) { _skip(_u64()); }
      return;
    }
    throw const FormatException('Unknown GGUF metadata type.');
  }
  Object? _value(int type) {
    if (type == 8) return _string();
    if (type == 4) return _u32();
    if (type == 10) return _u64();
    if (type == 0 || type == 2) {
      final b = ByteData.sublistView(_read(_sizes[type]!));
      return type == 0 ? b.getUint8(0) : b.getUint16(0, Endian.little);
    }
    _skipValue(type);
    return null;
  }
  GgufMetadata parse() {
    if (ascii.decode(_read(4)) != 'GGUF') throw const FormatException('Not a GGUF file.');
    final version = _u32();
    if (version != 2 && version != 3) throw const FormatException('Unsupported GGUF metadata version.');
    _u64(); // tensor count
    final count = _u64();
    if (count > length ~/ 12) throw const FormatException('Invalid GGUF metadata count.');
    final values = <String, Object>{};
    for (var i = 0; i < count; i++) {
      final key = _string();
      final type = _u32();
      final wanted = key == 'general.architecture' || key == 'general.name' || key == 'general.file_type' || key.endsWith('.context_length') || key.endsWith('.block_count') || key.endsWith('.embedding_length') || key.endsWith('.attention.head_count') || key.endsWith('.attention.head_count_kv') || key.endsWith('.attention.key_length') || key.endsWith('.attention.value_length');
      if (wanted) {
        final value = _value(type);
        if (value != null) values[key] = value;
      } else {
        _skipValue(type);
      }
    }
    return GgufMetadata(Map.unmodifiable(values), length);
  }
}
