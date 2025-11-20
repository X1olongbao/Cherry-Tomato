package com.example.tomatonator

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.tomatonator/installed_apps"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    try {
                        val apps = getLaunchableApps()
                        result.success(apps)
                    } catch (e: Exception) {
                        result.error("ERR_APPS", e.message, null)
                    }
                }
                "getAppIcon" -> {
                    try {
                        val pkg = call.argument<String>("package")
                        if (pkg.isNullOrEmpty()) {
                            result.error("ERR_ARGS", "package is required", null)
                        } else {
                            val bytes = getAppIconBytes(pkg)
                            if (bytes != null) result.success(bytes) else result.success(null)
                        }
                    } catch (e: Exception) {
                        result.error("ERR_ICON", e.message, null)
                    }
                }
                "isUsageAccessGranted" -> {
                    result.success(isUsageAccessGranted())
                }
                "openUsageAccessSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERR_SETTINGS", e.message, null)
                    }
                }
                "isOverlayPermissionGranted" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "openOverlaySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                            data = android.net.Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERR_SETTINGS", e.message, null)
                    }
                }
                "startAppBlocker" -> {
                    try {
                        val pkgs = (call.argument<List<String>>("packages") ?: emptyList())
                        val intent = Intent(this, AppBlockerService::class.java)
                        intent.putStringArrayListExtra(AppBlockerService.EXTRA_BLOCKED_PACKAGES, ArrayList(pkgs))
                        // Dismiss duration is fixed at 30 seconds in AppBlockerService
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            ContextCompat.startForegroundService(this, intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERR_SERVICE", e.message, null)
                    }
                }
                "stopAppBlocker" -> {
                    try {
                        val intent = Intent(this, AppBlockerService::class.java)
                        stopService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERR_SERVICE", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getLaunchableApps(): List<Map<String, String>> {
        val pm: PackageManager = applicationContext.packageManager
        val intent = Intent(Intent.ACTION_MAIN, null)
        intent.addCategory(Intent.CATEGORY_LAUNCHER)
        val resolveInfos = pm.queryIntentActivities(intent, 0)

        val seen = HashSet<String>()
        val list = ArrayList<Map<String, String>>()

        for (ri in resolveInfos) {
            val pkg = ri.activityInfo.packageName ?: continue
            if (seen.contains(pkg)) continue
            seen.add(pkg)
            val appName = ri.loadLabel(pm)?.toString() ?: pkg
            val map = hashMapOf(
                "name" to appName,
                "package" to pkg
            )
            list.add(map)
        }
        return list.sortedBy { it["name"]?.lowercase() ?: "" }
    }

    private fun isUsageAccessGranted(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }

    private fun getAppIconBytes(packageName: String): ByteArray? {
        return try {
            val pm = applicationContext.packageManager
            val drawable: Drawable = pm.getApplicationIcon(packageName)
            val bitmap: Bitmap = if (drawable is BitmapDrawable) {
                drawable.bitmap
            } else {
                val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
                val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
                val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bmp)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
                bmp
            }
            val stream = java.io.ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            null
        }
    }
}
