package app.dayark.metersystem

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dayark/ai_hardware")
            .setMethodCallHandler { call, result ->
                if (call.method != "detect") {
                    result.notImplemented()
                } else {
                    try {
                        val path = call.argument<String>("storagePath") ?: filesDir.path
                        val memory = ActivityManager.MemoryInfo()
                        (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager)
                            .getMemoryInfo(memory)
                        result.success(mapOf(
                            "totalMemoryBytes" to memory.totalMem,
                            "availableMemoryBytes" to memory.availMem,
                            "freeStorageBytes" to StatFs(path).availableBytes,
                            "cpu" to "${Build.HARDWARE} (${Build.SUPPORTED_ABIS.joinToString()})"
                        ))
                    } catch (error: Exception) {
                        result.error("hardware_unavailable", "Hardware counters unavailable", null)
                    }
                }
            }
    }
}
