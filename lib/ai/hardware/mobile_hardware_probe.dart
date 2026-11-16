import 'package:flutter/services.dart';

/// Optional native counters; absence must not prevent use of remote providers.
Future<Map<Object?, Object?>> readMobileAiHardware(String storagePath) async {
  try {
    return await const MethodChannel('dayark/ai_hardware')
            .invokeMapMethod<Object?, Object?>('detect', {
              'storagePath': storagePath,
            }) ??
        {};
  } on MissingPluginException {
    return {};
  } on PlatformException {
    return {};
  }
}
