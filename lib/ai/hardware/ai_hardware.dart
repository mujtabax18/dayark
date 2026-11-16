/// Unknown measurements remain null; they must never imply compatibility.
class AiHardwareReport {
  AiHardwareReport({
    required this.platform,
    required this.cpu,
    required this.logicalCores,
    this.totalMemoryBytes,
    this.availableMemoryBytes,
    this.freeStorageBytes,
    this.gpu,
    this.vramBytes,
    this.runtimeSupported,
    Iterable<String> notes = const [],
  }) : notes = List.unmodifiable(notes);

  final String platform;
  final String cpu;
  final int logicalCores;
  final int? totalMemoryBytes;
  final int? availableMemoryBytes;
  final int? freeStorageBytes;
  final String? gpu;
  final int? vramBytes;
  final bool? runtimeSupported;
  final List<String> notes;
}
