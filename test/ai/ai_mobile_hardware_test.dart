import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/ai/hardware/mobile_hardware_probe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'mobile hardware channel forwards destination and preserves counters',
    () async {
      const channel = MethodChannel('dayark/ai_hardware');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'detect');
            expect(call.arguments, {'storagePath': '/models'});
            return {'totalMemoryBytes': 123, 'availableMemoryBytes': 45};
          });
      expect(
        (await readMobileAiHardware('/models'))['availableMemoryBytes'],
        45,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      expect(await readMobileAiHardware('/models'), isEmpty);
    },
  );
}
