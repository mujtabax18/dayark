import Flutter
import UIKit
import Metal
import os

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DayArkAiHardware") {
      let channel = FlutterMethodChannel(name: "dayark/ai_hardware", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "detect" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let arguments = call.arguments as? [String: Any]
        let path = arguments?["storagePath"] as? String ?? NSHomeDirectory()
        var report: [String: Any] = [
          "totalMemoryBytes": ProcessInfo.processInfo.physicalMemory,
          // Available allocation budget, rather than total physical free RAM.
          "availableMemoryBytes": os_proc_available_memory(),
          "cpu": "Apple (\(ProcessInfo.processInfo.processorCount) logical cores)"
        ]
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: path),
           let free = attributes[.systemFreeSize] as? NSNumber {
          report["freeStorageBytes"] = free
        }
        if let device = MTLCreateSystemDefaultDevice() {
          report["gpu"] = device.name
        }
        result(report)
      }
    }
  }
}
