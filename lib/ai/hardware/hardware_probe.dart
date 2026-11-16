import 'ai_hardware.dart';
import 'hardware_probe_stub.dart'
    if (dart.library.io) 'hardware_probe_io.dart'
    as platform;

/// Probes only local resources. storagePath must be the model destination volume.
Future<AiHardwareReport> detectAiHardware({required String storagePath}) =>
    platform.detect(storagePath);
