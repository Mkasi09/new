package za.co.phephamv.isdp

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "za.co.phephamv.isdp/device_services"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isGooglePlayServicesAvailable" -> {
                    result.success(isGooglePlayServicesInstalled())
                }
                "isHuaweiMobileServicesAvailable" -> {
                    result.success(isHuaweiMobileServicesInstalled())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isGooglePlayServicesInstalled(): Boolean {
        return try {
            val info = packageManager.getApplicationInfo(
                "com.google.android.gms",
                PackageManager.GET_META_DATA
            )
            info.enabled
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun isHuaweiMobileServicesInstalled(): Boolean {
        return try {
            val info = packageManager.getApplicationInfo(
                "com.huawei.hwid",
                PackageManager.GET_META_DATA
            )
            info.enabled
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }
}
