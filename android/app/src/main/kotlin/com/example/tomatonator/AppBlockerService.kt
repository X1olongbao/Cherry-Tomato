package com.example.tomatonator

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.TextView
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import androidx.core.app.NotificationCompat
import java.util.Timer
import java.util.TimerTask

class AppBlockerService : Service() {
    companion object {
        const val CHANNEL_ID = "tomatonator_app_blocker"
        const val NOTIFICATION_ID = 1001
        const val EXTRA_BLOCKED_PACKAGES = "blocked_packages"
    }

    private var blockedPackages: Set<String> = emptySet()
    private var timer: Timer? = null
    private var wm: WindowManager? = null
    private var overlayView: View? = null

    override fun onCreate() {
        super.onCreate()
        wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val list = intent?.getStringArrayListExtra(EXTRA_BLOCKED_PACKAGES) ?: arrayListOf()
        blockedPackages = list.toSet()
        startForeground(NOTIFICATION_ID, buildNotification())
        startMonitoring()
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        stopMonitoring()
        removeOverlay()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(CHANNEL_ID, "App Blocker", NotificationManager.IMPORTANCE_LOW)
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Cherry Tomato App Blocker")
            .setContentText("Monitoring foreground apps to block distractions")
            .setSmallIcon(android.R.drawable.stat_notify_more)
            .setOngoing(true)
            .build()
    }

    private fun startMonitoring() {
        stopMonitoring()
        timer = Timer()
        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                try {
                    val top = getTopAppPackage()
                    if (top != null && blockedPackages.contains(top)) {
                        showOverlay()
                    } else {
                        removeOverlay()
                    }
                } catch (_: Exception) {
                }
            }
        }, 1000, 1000)
    }

    private fun stopMonitoring() {
        timer?.cancel()
        timer = null
    }

    private fun getTopAppPackage(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(now - 5000, now)
        val event = UsageEvents.Event()
        var lastPkg: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                lastPkg = event.packageName
            }
        }
        return lastPkg
    }

    private fun showOverlay() {
        if (!Settings.canDrawOverlays(this)) return
        if (overlayView != null) return

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            android.graphics.PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.CENTER

        val root = FrameLayout(this)
        root.setBackgroundColor(Color.argb(220, 0, 0, 0))

        val text = TextView(this)
        text.text = "Blocked by Cherry Tomato"
        text.setTextColor(Color.WHITE)
        text.textSize = 20f
        text.gravity = Gravity.CENTER

        val button = Button(this)
        button.text = "Go Back"
        button.setOnClickListener {
            // Minimize the blocked app by sending user to home screen
            val home = Intent(Intent.ACTION_MAIN)
            home.addCategory(Intent.CATEGORY_HOME)
            home.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(home)
            removeOverlay()
        }

        val container = FrameLayout(this)
        val lpText = FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT)
        lpText.gravity = Gravity.CENTER
        val lpButton = FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT)
        lpButton.gravity = Gravity.CENTER or Gravity.BOTTOM
        lpButton.bottomMargin = 120

        container.addView(text, lpText)
        container.addView(button, lpButton)
        root.addView(container)

        overlayView = root
        wm?.addView(overlayView, params)
    }

    private fun removeOverlay() {
        overlayView?.let {
            try { wm?.removeView(it) } catch (_: Exception) {}
        }
        overlayView = null
    }
}