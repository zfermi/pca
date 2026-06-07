package com.parentalcontrol.tv_parental_control

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.CountDownTimer
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class TimerService : Service() {

    private var countDownTimer: CountDownTimer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    companion object {
        const val ACTION_START = "ACTION_START"
        const val ACTION_STOP = "ACTION_STOP"
        const val ACTION_ADD_TIME = "ACTION_ADD_TIME"
        const val EXTRA_CHILD_ID = "child_id"
        const val EXTRA_CHILD_NAME = "child_name"
        const val EXTRA_MINUTES = "minutes"
        const val EXTRA_PIN_HASH = "pin_hash"

        const val CHANNEL_ID = "tv_timer_channel"
        const val ALERT_CHANNEL_ID = "tv_alert_channel"
        const val NOTIFICATION_ID = 2001
        const val WARNING_NOTIFICATION_ID = 2002

        @Volatile var isRunning = false
            private set
        @Volatile var remainingSeconds: Long = 0
            private set
        @Volatile var totalSeconds: Long = 0
            private set
        @Volatile var activeChildId: Int = -1
            private set
        @Volatile var activeChildName: String = ""
            private set
        @Volatile var pinHash: String = ""
            private set
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                activeChildId = intent.getIntExtra(EXTRA_CHILD_ID, -1)
                activeChildName = intent.getStringExtra(EXTRA_CHILD_NAME) ?: ""
                val minutes = intent.getIntExtra(EXTRA_MINUTES, 0)
                pinHash = intent.getStringExtra(EXTRA_PIN_HASH) ?: ""

                if (activeChildId != -1 && minutes > 0) {
                    totalSeconds = minutes * 60L
                    remainingSeconds = totalSeconds
                    isRunning = true

                    startForeground(NOTIFICATION_ID, buildNotification())
                    acquireWakeLock()
                    startCountdown()
                }
            }
            ACTION_STOP -> {
                stopCountdown()
                OverlayLockScreen.dismiss(this)
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            ACTION_ADD_TIME -> {
                val extraMinutes = intent.getIntExtra(EXTRA_MINUTES, 0)
                remainingSeconds += extraMinutes * 60L
                totalSeconds += extraMinutes * 60L
                // If overlay is showing and we got bonus time, dismiss it
                if (remainingSeconds > 0) {
                    OverlayLockScreen.dismiss(this)
                    if (countDownTimer == null) {
                        startCountdown()
                    }
                }
            }
        }
        return START_STICKY
    }

    private fun startCountdown() {
        countDownTimer?.cancel()

        countDownTimer = object : CountDownTimer(remainingSeconds * 1000, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                remainingSeconds = millisUntilFinished / 1000
                updateNotification()

                if (remainingSeconds == 300L) {
                    showWarning("${activeChildName}: 5 minutes of TV time left!")
                } else if (remainingSeconds == 60L) {
                    showWarning("${activeChildName}: 1 minute of TV time left!")
                }
            }

            override fun onFinish() {
                remainingSeconds = 0
                isRunning = false
                updateNotification()
                showTimeUpOverlay()
            }
        }.start()
    }

    private fun stopCountdown() {
        countDownTimer?.cancel()
        countDownTimer = null
        isRunning = false
        activeChildId = -1
        activeChildName = ""
        remainingSeconds = 0
        totalSeconds = 0
        releaseWakeLock()
    }

    private fun showTimeUpOverlay() {
        OverlayLockScreen.show(this, pinHash)
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val timerChannel = NotificationChannel(
                CHANNEL_ID,
                "TV Timer",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows remaining TV time"
                setShowBadge(false)
            }

            val alertChannel = NotificationChannel(
                ALERT_CHANNEL_ID,
                "Time Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts when TV time is running out"
                enableVibration(true)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(timerChannel)
            manager.createNotificationChannel(alertChannel)
        }
    }

    private fun buildNotification(): Notification {
        val timeText = if (remainingSeconds > 0) {
            formatTime(remainingSeconds)
        } else {
            "Time's up!"
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("TV Time: $activeChildName")
            .setContentText("Remaining: $timeText")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun updateNotification() {
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, buildNotification())
        } catch (_: Exception) {}
    }

    private fun showWarning(message: String) {
        try {
            val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
                .setContentTitle("TV Time Warning")
                .setContentText(message)
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .build()

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(WARNING_NOTIFICATION_ID, notification)
        } catch (_: Exception) {}
    }

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "tvpca::TimerWakeLock"
        ).apply {
            acquire(totalSeconds * 1000L + 60000L)
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    private fun formatTime(seconds: Long): String {
        val h = seconds / 3600
        val m = (seconds % 3600) / 60
        val s = seconds % 60
        return if (h > 0) {
            String.format("%d:%02d:%02d", h, m, s)
        } else {
            String.format("%02d:%02d", m, s)
        }
    }

    override fun onDestroy() {
        stopCountdown()
        super.onDestroy()
    }
}
