import 'ai_hardware.dart';

Future<AiHardwareReport> detect(String path) async => AiHardwareReport(
  platform: 'web',
  cpu: 'Unknown',
  logicalCores: 0,
  runtimeSupported: false,
  notes: ['Local GGUF inference is unavailable on web.'],
);
