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
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import androidx.core.app.NotificationCompat
import java.util.Timer
import java.util.TimerTask

class AppBlockerService : Service() {
    companion object {
        const val CHANNEL_ID = "tomatonator_app_blocker"
        const val NOTIFICATION_ID = 1001
        const val EXTRA_BLOCKED_PACKAGES = "blocked_packages"
        const val EXTRA_DISMISS_DURATION = "dismiss_duration_seconds"
        const val DISMISS_DURATION = 30 // Fixed 30 seconds
    }

    private var blockedPackages: Set<String> = emptySet()
    private var dismissDurationSeconds: Int = DISMISS_DURATION
    private var timer: Timer? = null
    private var dismissTimer: Timer? = null
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
        dismissDurationSeconds = DISMISS_DURATION // Fixed 30 seconds
        android.util.Log.d("AppBlockerService", "Service started with ${blockedPackages.size} blocked packages: $blockedPackages")
        startForeground(NOTIFICATION_ID, buildNotification())
        startMonitoring()
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        stopMonitoring()
        cancelDismissTimer()
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
        // Immediately check once to catch apps already in foreground when service starts
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            try {
                val top = getTopAppPackage()
                if (top != null && blockedPackages.contains(top)) {
                    showOverlay()
                }
            } catch (e: Exception) {
                android.util.Log.e("AppBlockerService", "Error in initial check: ${e.message}")
            }
        }, 200) // Small delay to ensure service is ready
        
        timer = Timer()
        // Check more frequently (every 500ms) for better responsiveness
        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                try {
                    val top = getTopAppPackage()
                    android.util.Log.d("AppBlockerService", "Monitoring: top app = $top, blocked = ${blockedPackages.contains(top ?: "")}")
                    if (top != null && blockedPackages.contains(top)) {
                        android.util.Log.d("AppBlockerService", "Blocked app detected: $top, showing overlay")
                        // Show overlay - must run on main thread
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            showOverlay()
                        }
                    } else {
                        // Only remove if we're showing overlay for a different app
                        if (overlayView != null && top != null && !blockedPackages.contains(top)) {
                            android.util.Log.d("AppBlockerService", "Non-blocked app detected: $top, removing overlay")
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                removeOverlay()
                            }
                        }
                    }
                } catch (e: Exception) {
                    // Log error for debugging
                    android.util.Log.e("AppBlockerService", "Error in monitoring: ${e.message}", e)
                }
            }
        }, 500, 500) // Check every 500ms for faster detection
    }

    private fun stopMonitoring() {
        timer?.cancel()
        timer = null
    }

    private fun getTopAppPackage(): String? {
        try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            
            // Method 1: Check current foreground app using queryUsageStats
            // This gives us the most recently used apps
            val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_BEST, now - 10000, now)
            if (stats != null && stats.isNotEmpty()) {
                // Sort by last time used (most recent first)
                val sortedStats = stats.sortedByDescending { it.lastTimeUsed }
                if (sortedStats.isNotEmpty()) {
                    val topApp = sortedStats[0]
                    val timeSinceLastUsed = now - topApp.lastTimeUsed
                    // Only return if it was used very recently (within last 2 seconds)
                    if (timeSinceLastUsed < 2000) {
                        android.util.Log.d("AppBlockerService", "Detected app via stats: ${topApp.packageName} (used ${timeSinceLastUsed}ms ago)")
                        return topApp.packageName
                    } else {
                        android.util.Log.d("AppBlockerService", "Top app ${topApp.packageName} was used ${timeSinceLastUsed}ms ago (too old)")
                    }
                }
            }
            
            // Method 2: Fallback to events (for immediate detection)
            val events = usm.queryEvents(now - 3000, now)
            val event = UsageEvents.Event()
            var lastPkg: String? = null
            var lastEventTime = 0L
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                    event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                    if (event.timeStamp > lastEventTime) {
                        lastEventTime = event.timeStamp
                        lastPkg = event.packageName
                    }
                }
            }
            if (lastPkg != null) {
                android.util.Log.d("AppBlockerService", "Detected app via events: $lastPkg")
            }
            return lastPkg
        } catch (e: Exception) {
            android.util.Log.e("AppBlockerService", "Error getting top app: ${e.message}", e)
            return null
        }
    }

    private fun showOverlay() {
        android.util.Log.d("AppBlockerService", "showOverlay() called")
        if (!Settings.canDrawOverlays(this)) {
            android.util.Log.w("AppBlockerService", "Cannot show overlay: permission not granted")
            return
        }
        if (overlayView != null) {
            android.util.Log.d("AppBlockerService", "Overlay already showing, skipping")
            return
        }
        android.util.Log.d("AppBlockerService", "Creating and showing overlay for blocked app")

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
        root.setBackgroundColor(Color.argb(240, 0, 0, 0))

        // Main container with rounded corners
        val container = FrameLayout(this)
        container.setBackgroundColor(Color.argb(255, 255, 255, 255))
        container.setPadding(40, 40, 40, 40)
        
        val containerParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        )
        containerParams.gravity = Gravity.CENTER
        
        // Warning icon
        val iconView = TextView(this)
        iconView.text = "⚠️"
        iconView.textSize = 64f
        iconView.gravity = Gravity.CENTER
        
        // Warning text
        val text = TextView(this)
        text.text = "Blocked App Detected"
        text.setTextColor(Color.argb(255, 33, 33, 33))
        text.textSize = 24f
        text.gravity = Gravity.CENTER
        text.setTypeface(null, android.graphics.Typeface.BOLD)
        
        // Subtitle
        val subtitle = TextView(this)
        subtitle.text = "This app is blocked during your Pomodoro session"
        subtitle.setTextColor(Color.argb(255, 100, 100, 100))
        subtitle.textSize = 16f
        subtitle.gravity = Gravity.CENTER
        subtitle.setPadding(0, 16, 0, 32)
        
        // Countdown text
        val countdownText = TextView(this)
        countdownText.text = "Dismissing in ${dismissDurationSeconds}s"
        countdownText.setTextColor(Color.argb(255, 150, 150, 150))
        countdownText.textSize = 14f
        countdownText.gravity = Gravity.CENTER
        countdownText.setPadding(0, 0, 0, 24)
        
        // Go back button
        val button = Button(this)
        button.text = "Go Back to Focus"
        button.setBackgroundColor(Color.argb(255, 229, 57, 53)) // Tomato red
        button.setTextColor(Color.WHITE)
        button.textSize = 16f
        button.setPadding(32, 16, 32, 16)
        button.setOnClickListener {
            val home = Intent(Intent.ACTION_MAIN)
            home.addCategory(Intent.CATEGORY_HOME)
            home.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(home)
            removeOverlay()
        }

        val iconParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        )
        iconParams.gravity = Gravity.CENTER_HORIZONTAL
        iconParams.bottomMargin = 200
        
        val textParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        )
        textParams.gravity = Gravity.CENTER_HORIZONTAL
        textParams.topMargin = 280
        
        val subtitleParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        )
        subtitleParams.gravity = Gravity.CENTER_HORIZONTAL
        subtitleParams.topMargin = 340
        
        val countdownParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        )
        countdownParams.gravity = Gravity.CENTER_HORIZONTAL
        countdownParams.topMargin = 400
        
        val buttonParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        )
        buttonParams.gravity = Gravity.CENTER_HORIZONTAL or Gravity.BOTTOM
        buttonParams.bottomMargin = 40

        container.addView(iconView, iconParams)
        container.addView(text, textParams)
        container.addView(subtitle, subtitleParams)
        container.addView(countdownText, countdownParams)
        container.addView(button, buttonParams)
        root.addView(container, containerParams)

        overlayView = root
        try {
            wm?.addView(overlayView, params)
            android.util.Log.d("AppBlockerService", "Overlay added to window manager successfully")
            // Start countdown and auto-dismiss
            startDismissTimer(countdownText)
        } catch (e: Exception) {
            android.util.Log.e("AppBlockerService", "Failed to add overlay to window: ${e.message}", e)
            overlayView = null
        }
    }
    
    private fun startDismissTimer(countdownText: TextView) {
        cancelDismissTimer()
        var remaining = dismissDurationSeconds
        dismissTimer = Timer()
        dismissTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                remaining--
                if (remaining > 0) {
                    // Update countdown text on main thread
                    overlayView?.post {
                        countdownText.text = "Dismissing in ${remaining}s"
                    }
                } else {
                    // Auto-dismiss
                    overlayView?.post {
                        removeOverlay()
                    }
                    cancel()
                }
            }
        }, 1000, 1000)
    }
    
    private fun cancelDismissTimer() {
        dismissTimer?.cancel()
        dismissTimer = null
    }

    private fun removeOverlay() {
        cancelDismissTimer()
        overlayView?.let {
            try { wm?.removeView(it) } catch (_: Exception) {}
        }
        overlayView = null
    }
}