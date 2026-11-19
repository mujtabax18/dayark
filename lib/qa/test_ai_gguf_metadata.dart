// Standalone native Dart test: dart run lib/qa/test_ai_gguf_metadata.dart
// Run from a project where this archive has been copied into lib/.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../ai/model_manager/gguf_metadata.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  final dir = await Directory.systemTemp.createTemp('dayark-gguf-');
  try {
    final bytes = BytesBuilder();
    void u32(int n) => bytes.add((ByteData(4)..setUint32(0, n, Endian.little)).buffer.asUint8List());
    void u64(int n) => bytes.add((ByteData(8)..setUint64(0, n, Endian.little)).buffer.asUint8List());
    void str(String s) { final data = utf8.encode(s); u64(data.length); bytes.add(data); }
    void text(String k, String v) { str(k); u32(8); str(v); }
    void integer(String k, int v) { str(k); u32(4); u32(v); }
    bytes.add(ascii.encode('GGUF')); u32(3); u64(0); u64(8);
    text('general.architecture', 'custom_arch');
    integer('custom_arch.context_length', 32768);
    integer('custom_arch.block_count', 22);
    integer('custom_arch.embedding_length', 2048);
    integer('custom_arch.attention.head_count', 32);
    integer('custom_arch.attention.head_count_kv', 4);
    // String arrays must be skipped without allocating tensor/tokenizer data.
    str('tokenizer.ggml.tokens'); u32(9); u32(8); u64(2); str('test'); str('hello');
    integer('general.file_type', 10);
    final file = File('${dir.path}/fixture.gguf');
    await file.writeAsBytes(bytes.takeBytes());
    final model = await GgufMetadata.read(file.path);
    check(model.architecture == 'custom_arch', 'Architecture not detected');
    check(model.nativeContext == 32768, 'Context not detected');
    check(model.fileType == 10, 'File type not detected');
    check(model.kvBytesPerToken == 22528, 'Incorrect KV estimate');
    final low = model.chooseContext(512 * 1024 * 1024, null);
    final high = model.chooseContext(8 * 1024 * 1024 * 1024, null);
    check(low > 0 && low < high && high <= 32768, 'Context is not device bounded');
    await file.writeAsBytes([71, 71, 85, 70]);
    var rejected = false;
    try { await GgufMetadata.read(file.path); } on FormatException { rejected = true; }
    check(rejected, 'Truncated metadata must be rejected');
    stdout.writeln('GGUF metadata and context policy checks passed.');
  } finally {
    await dir.delete(recursive: true);
  }
}
