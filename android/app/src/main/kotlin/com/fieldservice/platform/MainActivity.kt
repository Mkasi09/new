package com.fieldservice.platform

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.fieldservice.platform/device_services"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isGooglePlayServicesAvailable" -> {
                    result.success(isGooglePlayServicesInstalled())
                }
                "isHuaweiMobileServicesAvailable" -> {
                    result.success(isHuaweiMobileServicesInstalled())
                }
                "isHuaweiDevice" -> {
                    result.success(isHuaweiOrHonorDevice())
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

    private fun isHuaweiOrHonorDevice(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        return manufacturer.contains("huawei") ||
            manufacturer.contains("honor") ||
            brand.contains("huawei") ||
            brand.contains("honor")
    }
}
