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
import android.widget.LinearLayout
import android.widget.ImageView
import android.graphics.drawable.GradientDrawable
import android.app.usage.UsageEvents
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import androidx.core.app.NotificationCompat
import android.util.Log
import java.util.Timer
import java.util.TimerTask

class AppBlockerService : Service() {
    companion object {
        const val CHANNEL_ID = "tomatonator_app_blocker"
        const val NOTIFICATION_ID = 1001
        const val EXTRA_BLOCKED_PACKAGES = "blocked_packages"
        const val EXTRA_DISMISS_DURATION = "dismiss_duration_seconds"
        const val DISMISS_DURATION = 30
    }

    private var blockedPackages: Set<String> = emptySet()
    private var dismissDurationSeconds: Int = DISMISS_DURATION
    private var dismissEndAt: Long? = null
    private var timer: Timer? = null
    private var countdownTimer: Timer? = null // Timer for updating countdown display
    private var wm: WindowManager? = null
    private var overlayView: View? = null
    private var currentBlockedApp: String? = null // Track which app is currently blocked
    private var countdownTextView: TextView? = null // Keep reference to update countdown

    override fun onCreate() {
        super.onCreate()
        wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        Log.d("AppBlockerService", "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val list = intent?.getStringArrayListExtra(EXTRA_BLOCKED_PACKAGES) ?: arrayListOf()
        
        // If we have new packages, update them; otherwise keep existing ones (for service restart)
        if (list.isNotEmpty()) {
            blockedPackages = list.toSet()
        }
        
        val provided = intent?.getIntExtra(EXTRA_DISMISS_DURATION, DISMISS_DURATION) ?: DISMISS_DURATION
        
        // Only update duration if provided and valid
        if (provided > 0) {
            dismissDurationSeconds = provided
            dismissEndAt = System.currentTimeMillis() + dismissDurationSeconds * 1000L
        }
        
        Log.d("AppBlockerService", "Started with ${blockedPackages.size} blocked packages: $blockedPackages, dismiss in ${dismissDurationSeconds}s")
        startForeground(NOTIFICATION_ID, buildNotification())
        
        // Only restart monitoring if not already running
        if (timer == null) {
            startMonitoring()
        }
        
        // Update countdown if overlay is already showing
        updateCountdownText()
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        stopMonitoring()
        removeOverlay()
        Log.d("AppBlockerService", "Service destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Blocker - Focus Mode",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Keeps app blocker active during Pomodoro sessions"
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Cherry Tomato - Focus Mode Active")
            .setContentText("App blocker is protecting your focus time")
            .setSmallIcon(android.R.drawable.stat_notify_more)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun startMonitoring() {
        stopMonitoring()
        Log.d("AppBlockerService", "Start monitoring")
        // Immediately check once to catch apps already in foreground when service starts
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            try {
                val top = getTopAppPackage()
                if (top != null && blockedPackages.contains(top)) {
                    showOverlay()
                    Log.d("AppBlockerService", "Initial overlay shown for $top")
                }
            } catch (ex: Exception) { Log.w("AppBlockerService", "Initial check failed: ${ex.message}") }
        }, 200) // Small delay to ensure service is ready
        
        timer = Timer()
        // Check more frequently (every 200ms) for better responsiveness
        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                try {
                    val top = getTopAppPackage()
                    if (top != null && blockedPackages.contains(top)) {
                        // Track this as the currently blocked app
                        currentBlockedApp = top
                        // Show overlay immediately - must run on main thread
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            showOverlay()
                            Log.d("AppBlockerService", "Overlay shown for $top")
                        }
                    } else if (currentBlockedApp != null && overlayView != null) {
                        // Keep overlay visible even when switching away from blocked app
                        // This prevents bypass - overlay stays until user clicks button
                        Log.v("AppBlockerService", "Keeping overlay visible (current: $top, blocked: $currentBlockedApp)")
                    }
                } catch (ex: Exception) { Log.w("AppBlockerService", "Monitor loop error: ${ex.message}") }
            }
        }, 200, 200) // Check every 200ms for faster detection
    }

    private fun stopMonitoring() {
        timer?.cancel()
        timer = null
        Log.d("AppBlockerService", "Stop monitoring")
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
                        return topApp.packageName
                    } else {
                        Log.v("AppBlockerService", "Top app ${topApp.packageName} last used ${timeSinceLastUsed}ms ago; ignoring")
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
            
            Log.v("AppBlockerService", "Fallback detected top app: $lastPkg")
            return lastPkg
        } catch (ex: Exception) {
            Log.e("AppBlockerService", "getTopAppPackage failed: ${ex.message}")
            return null
        }
    }

    private fun showOverlay() {
        if (!Settings.canDrawOverlays(this)) {
            Log.w("AppBlockerService", "Overlay permission missing")
            return
        }
        if (overlayView != null) {
            Log.v("AppBlockerService", "Overlay already visible")
            return
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            android.graphics.PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.CENTER

        val root = FrameLayout(this)
        root.setBackgroundColor(Color.argb(220, 0, 0, 0))

        val container = LinearLayout(this)
        container.orientation = LinearLayout.VERTICAL
        container.gravity = Gravity.CENTER_HORIZONTAL
        container.setPadding(48, 40, 48, 32)

        val cardBg = GradientDrawable()
        cardBg.shape = GradientDrawable.RECTANGLE
        cardBg.setColor(Color.WHITE)
        cardBg.cornerRadius = 24f
        cardBg.setStroke(2, Color.argb(255, 229, 57, 53))
        container.background = cardBg
        container.elevation = 16f

        val containerParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        )
        containerParams.gravity = Gravity.CENTER

        val icon = ImageView(this)
        icon.setImageResource(android.R.drawable.ic_dialog_alert)
        icon.setColorFilter(Color.argb(255, 229, 57, 53))
        val iconLp = LinearLayout.LayoutParams(96, 96)

        val title = TextView(this)
        title.text = "App Blocked During Focus"
        title.setTextColor(Color.argb(255, 33, 33, 33))
        title.textSize = 20f
        title.setTypeface(null, android.graphics.Typeface.BOLD)
        val titleLp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        titleLp.topMargin = 16

        val subtitle = TextView(this)
        subtitle.text = "Stay focused. Finish your Pomodoro session first."
        subtitle.setTextColor(Color.argb(255, 100, 100, 100))
        subtitle.textSize = 14f
        val subLp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        subLp.topMargin = 8

        val countdownText = TextView(this)
        countdownTextView = countdownText // Store reference
        val remainingSecInitial = ((dismissEndAt ?: System.currentTimeMillis()) - System.currentTimeMillis()).coerceAtLeast(0L) / 1000L
        countdownText.text = "Session ends in ${formatHms(remainingSecInitial.toInt())}"
        countdownText.setTextColor(Color.argb(255, 150, 150, 150))
        countdownText.textSize = 12f
        val countLp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        countLp.topMargin = 16

        val button = Button(this)
        button.text = "Go Back to Focus"
        button.setTextColor(Color.WHITE)
        button.textSize = 16f
        val btnBg = GradientDrawable()
        btnBg.shape = GradientDrawable.RECTANGLE
        btnBg.setColor(Color.argb(255, 229, 57, 53))
        btnBg.cornerRadius = 16f
        button.background = btnBg
        val btnLp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        btnLp.topMargin = 20

        button.setOnClickListener {
            val home = Intent(Intent.ACTION_MAIN)
            home.addCategory(Intent.CATEGORY_HOME)
            home.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(home)
            removeOverlay()
        }

        container.addView(icon, iconLp)
        container.addView(title, titleLp)
        container.addView(subtitle, subLp)
        container.addView(countdownText, countLp)
        container.addView(button, btnLp)
        root.addView(container, containerParams)

        overlayView = root
        try {
            wm?.addView(overlayView, params)
            startCountdownTimer() // Start updating the countdown
            Log.d("AppBlockerService", "Overlay added")
        } catch (ex: Exception) {
            overlayView = null
            countdownTextView = null
            Log.e("AppBlockerService", "Failed to add overlay: ${ex.message}")
        }
    }
    
    private fun startCountdownTimer() {
        stopCountdownTimer()
        countdownTimer = Timer()
        countdownTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                updateCountdownText()
            }
        }, 0, 1000) // Update every second
        Log.d("AppBlockerService", "Countdown timer started")
    }
    
    private fun stopCountdownTimer() {
        countdownTimer?.cancel()
        countdownTimer = null
    }
    
    private fun updateCountdownText() {
        val now = System.currentTimeMillis()
        val endAt = dismissEndAt ?: now
        val remainingMs = endAt - now
        val remaining = if (remainingMs > 0) (remainingMs / 1000L).toInt() else 0
        
        // Use Handler to update on main thread
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            try {
                countdownTextView?.text = "Session ends in ${formatHms(remaining)}"
                Log.v("AppBlockerService", "Countdown updated: ${formatHms(remaining)}")
            } catch (ex: Exception) {
                Log.w("AppBlockerService", "Failed to update countdown: ${ex.message}")
            }
        }
    }

    private fun formatHms(seconds: Int): String {
        val h = seconds / 3600
        val m = (seconds % 3600) / 60
        val s = seconds % 60
        return when {
            h > 0 -> "${h}h ${m}m ${s}s"
            m > 0 -> "${m}m ${s}s"
            else -> "${s}s"
        }
    }
    
    private fun removeOverlay() {
        stopCountdownTimer()
        overlayView?.let {
            try { wm?.removeView(it) } catch (_: Exception) {}
        }
        overlayView = null
        countdownTextView = null
        currentBlockedApp = null // Clear tracked app when overlay is removed
        Log.d("AppBlockerService", "Overlay removed")
    }
}
