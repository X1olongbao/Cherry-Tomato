package com.example.tomatonator

import android.app.AppOpsManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.Locale

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.example.tomatonator/installed_apps"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> result.success(getInstalledApps())
                    "getAppIcon" -> {
                        val pkg = call.argument<String>("package")
                        if (pkg.isNullOrEmpty()) {
                            result.error("INVALID_ARGS", "package is required", null)
                        } else {
                            result.success(getAppIconBytes(pkg))
                        }
                    }
                    "isUsageAccessGranted" -> result.success(isUsageAccessGranted())
                    "isOverlayPermissionGranted" -> result.success(Settings.canDrawOverlays(this))
                    "openUsageAccessSettings" -> {
                        openUsageAccessSettings()
                        result.success(null)
                    }
                    "openOverlaySettings" -> {
                        openOverlaySettings()
                        result.success(null)
                    }
                    "startAppBlocker" -> {
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        val dismissSeconds =
                            call.argument<Int>("dismissDurationSeconds") ?: 30
                        startAppBlocker(packages, dismissSeconds)
                        result.success(null)
                    }
                    "stopAppBlocker" -> {
                        stopAppBlocker()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = packageManager
        val apps = mutableListOf<Map<String, Any>>()
        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        packages.forEach { info ->
            val isSystem = (info.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            if (!isSystem) {
                val name = pm.getApplicationLabel(info).toString()
                apps.add(
                    mapOf(
                        "name" to name,
                        "package" to info.packageName
                    )
                )
            }
        }
        return apps.sortedBy { it["name"].toString().lowercase(Locale.getDefault()) }
    }

    private fun getAppIconBytes(packageName: String): ByteArray? {
        return try {
            val drawable = packageManager.getApplicationIcon(packageName)
            val width = drawable.intrinsicWidth.coerceAtLeast(64)
            val height = drawable.intrinsicHeight.coerceAtLeast(64)
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, width, height)
            drawable.draw(canvas)
            ByteArrayOutputStream().apply {
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, this)
            }.toByteArray()
        } catch (_: Exception) {
            null
        }
    }

    private fun isUsageAccessGranted(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings() {
        try {
            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
        } catch (_: ActivityNotFoundException) {
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
        }
    }

    private fun openOverlaySettings() {
        try {
            startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
        } catch (_: Exception) {
        }
    }

    private fun startAppBlocker(blockedPackages: List<String>, dismissSeconds: Int) {
        val intent = Intent(this, AppBlockerService::class.java).apply {
            putStringArrayListExtra(
                AppBlockerService.EXTRA_BLOCKED_PACKAGES,
                ArrayList(blockedPackages)
            )
            putExtra(AppBlockerService.EXTRA_DISMISS_SECONDS, dismissSeconds)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopAppBlocker() {
        stopService(Intent(this, AppBlockerService::class.java))
    }
}
