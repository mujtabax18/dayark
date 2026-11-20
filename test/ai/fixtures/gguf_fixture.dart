import 'dart:convert';
import 'dart:typed_data';

/// A valid metadata-only GGUF v3. Test runtimes never read tensor weights.
Uint8List ggufFixture({String name = 'Fixture', int context = 4096}) {
  final out = BytesBuilder();
  void u32(int value) => out.add(
    (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List(),
  );
  void u64(int value) => out.add(
    (ByteData(8)..setUint64(0, value, Endian.little)).buffer.asUint8List(),
  );
  void string(String value) {
    final bytes = utf8.encode(value);
    u64(bytes.length);
    out.add(bytes);
  }

  out.add(ascii.encode('GGUF'));
  u32(3);
  u64(0);
  u64(8);
  for (final entry in {
    'general.architecture': 'llama',
    'general.name': name,
  }.entries) {
    string(entry.key);
    u32(8);
    string(entry.value);
  }
  for (final entry in {
    'llama.context_length': context,
    'llama.block_count': 16,
    'llama.embedding_length': 512,
    'llama.attention.head_count': 8,
    'llama.attention.head_count_kv': 4,
    'general.file_type': 15,
  }.entries) {
    string(entry.key);
    u32(4);
    u32(entry.value);
  }
  return out.toBytes();
}
