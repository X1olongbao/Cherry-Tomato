package com.example.tomatonator

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import androidx.core.app.NotificationCompat
import java.util.Locale

class AppBlockerService : Service() {

    companion object {
        const val EXTRA_BLOCKED_PACKAGES = "blocked_packages"
        const val EXTRA_DISMISS_SECONDS = "dismiss_seconds"
        private const val CHANNEL_ID = "app_blocker_channel"
        private const val NOTIFICATION_ID = 42
        private const val POLL_INTERVAL_MS = 1500L
    }

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var usageStatsManager: UsageStatsManager
    private lateinit var windowManager: WindowManager

    private var blockedPackages: Set<String> = emptySet()
    private var dismissSeconds: Int = 30
    private var overlayView: View? = null
    private var overlayVisible = false
    private var lastForegroundApp: String? = null

    private val pollRunnable = object : Runnable {
        override fun run() {
            val currentApp = getForegroundApp()
            val shouldBlock = currentApp != null &&
                blockedPackages.any { pkg -> currentApp.equals(pkg, ignoreCase = true) }
            if (shouldBlock) {
                showOverlay(currentApp!!)
            } else {
                hideOverlay()
            }
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val packages = intent?.getStringArrayListExtra(EXTRA_BLOCKED_PACKAGES)
        blockedPackages = packages?.map { it.lowercase(Locale.getDefault()) }?.toSet() ?: emptySet()
        dismissSeconds = intent?.getIntExtra(EXTRA_DISMISS_SECONDS, 30) ?: 30
        startForeground(NOTIFICATION_ID, buildNotification())
        handler.post(pollRunnable)
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(pollRunnable)
        hideOverlay()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("App blocker active")
            .setContentText("Distracting apps are temporarily blocked.")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Blocker",
                NotificationManager.IMPORTANCE_LOW
            )
            nm.createNotificationChannel(channel)
        }
    }

    private fun showOverlay(currentApp: String) {
        if (overlayVisible) return
        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }
        val inflater = LayoutInflater.from(this)
        overlayView = inflater.inflate(R.layout.overlay_blocker, null).apply {
            val message = findViewById<TextView>(R.id.blockerMessage)
            message.text = "Stay focused! $currentApp is blocked."
            background = GradientDrawable().apply {
                setColor(0xCC000000.toInt())
                cornerRadius = 0f
            }
        }
        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }
        windowManager.addView(overlayView, params)
        overlayVisible = true
    }

    private fun hideOverlay() {
        if (overlayVisible && overlayView != null) {
            windowManager.removeView(overlayView)
            overlayView = null
            overlayVisible = false
        }
    }

    private fun getForegroundApp(): String? {
        val end = System.currentTimeMillis()
        val begin = end - 60_000
        val usageEvents = usageStatsManager.queryEvents(begin, end)
        var latestEvent: UsageEvents.Event? = null
        val event = UsageEvents.Event()
        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                if (latestEvent == null || event.timeStamp > latestEvent!!.timeStamp) {
                    latestEvent = UsageEvents.Event(event)
                }
            }
        }
        val pkg = latestEvent?.packageName
        if (pkg != null && pkg != lastForegroundApp) {
            lastForegroundApp = pkg
        }
        return pkg
    }
}