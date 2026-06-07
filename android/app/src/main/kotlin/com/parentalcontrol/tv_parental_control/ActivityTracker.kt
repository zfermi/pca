package com.parentalcontrol.tv_parental_control

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.os.Build
import android.util.Log

/**
 * Tracks foreground app activity and media sessions for remote monitoring.
 * Works alongside AppBlockerService (AccessibilityService) to detect
 * which app is in the foreground and what media is playing.
 */
class ActivityTracker private constructor() {

    companion object {
        private const val TAG = "ActivityTracker"
        private const val MAX_HISTORY = 50
        private const val MIN_ACTIVITY_DURATION_MS = 3000L // Ignore app switches < 3 seconds

        @Volatile
        private var _currentApp: String? = null

        @Volatile
        private var _currentAppLabel: String? = null

        @Volatile
        private var _currentMediaTitle: String? = null

        @Volatile
        private var _currentMediaArtist: String? = null

        @Volatile
        private var _lastAppChangeTime: Long = 0L

        @Volatile
        private var _isTracking: Boolean = false

        private val _activityHistory = mutableListOf<Map<String, Any?>>()

        // System packages to ignore for activity tracking
        private val IGNORED_PACKAGES = setOf(
            "com.android.systemui",
            "com.android.launcher",
            "com.android.launcher3",
            "com.google.android.tvlauncher",
            "com.google.android.leanbacklauncher",
            "com.android.settings",
            "com.android.inputmethod.latin",
            "com.google.android.inputmethod.latin",
            "com.android.packageinstaller"
        )

        /**
         * Called by AppBlockerService when foreground app changes.
         */
        fun onAppChanged(context: Context, packageName: String) {
            if (!_isTracking) return
            if (IGNORED_PACKAGES.contains(packageName) || packageName.startsWith("com.android.launcher")) return

            val now = System.currentTimeMillis()

            // If same app, skip
            if (packageName == _currentApp) return

            // Record the previous app if it was open long enough
            if (_currentApp != null && (now - _lastAppChangeTime) >= MIN_ACTIVITY_DURATION_MS) {
                val entry = mapOf<String, Any?>(
                    "packageName" to _currentApp,
                    "appLabel" to (_currentAppLabel ?: _currentApp),
                    "mediaTitle" to _currentMediaTitle,
                    "mediaArtist" to _currentMediaArtist,
                    "startTime" to _lastAppChangeTime,
                    "endTime" to now,
                    "durationSeconds" to ((now - _lastAppChangeTime) / 1000)
                )
                synchronized(_activityHistory) {
                    _activityHistory.add(0, entry)
                    if (_activityHistory.size > MAX_HISTORY) {
                        _activityHistory.removeAt(_activityHistory.size - 1)
                    }
                }
            }

            // Update current app
            _currentApp = packageName
            _currentAppLabel = getAppLabel(context, packageName)
            _currentMediaTitle = null
            _currentMediaArtist = null
            _lastAppChangeTime = now

            // Try to get media info
            updateMediaInfo(context)
        }

        /**
         * Get current activity state.
         */
        fun getCurrentActivity(): Map<String, Any?> {
            return mapOf(
                "packageName" to _currentApp,
                "appLabel" to _currentAppLabel,
                "mediaTitle" to _currentMediaTitle,
                "mediaArtist" to _currentMediaArtist,
                "startTime" to _lastAppChangeTime,
                "isTracking" to _isTracking
            )
        }

        /**
         * Get activity history.
         */
        fun getActivityHistory(limit: Int = 20): List<Map<String, Any?>> {
            synchronized(_activityHistory) {
                return _activityHistory.take(limit).toList()
            }
        }

        /**
         * Get new activities since the given timestamp and clear them from history.
         */
        fun getNewActivities(sinceTimestamp: Long): List<Map<String, Any?>> {
            synchronized(_activityHistory) {
                val newItems = _activityHistory.filter { entry ->
                    val endTime = entry["endTime"] as? Long ?: 0L
                    endTime > sinceTimestamp
                }
                return newItems.toList()
            }
        }

        fun startTracking() {
            _isTracking = true
            _lastAppChangeTime = System.currentTimeMillis()
            Log.d(TAG, "Activity tracking started")
        }

        fun stopTracking() {
            _isTracking = false
            _currentApp = null
            _currentAppLabel = null
            _currentMediaTitle = null
            _currentMediaArtist = null
            Log.d(TAG, "Activity tracking stopped")
        }

        fun isTracking(): Boolean = _isTracking

        fun clearHistory() {
            synchronized(_activityHistory) {
                _activityHistory.clear()
            }
        }

        /**
         * Update media info from active media sessions.
         */
        fun updateMediaInfo(context: Context) {
            try {
                val msm = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager
                    ?: return

                // Need notification listener permission for getActiveSessions
                val componentName = ComponentName(context, AppBlockerService::class.java)
                val controllers = try {
                    msm.getActiveSessions(null)
                } catch (e: SecurityException) {
                    // Notification listener permission not granted — try without component
                    try {
                        msm.getActiveSessions(null)
                    } catch (_: Exception) {
                        emptyList<MediaController>()
                    }
                }

                for (controller in controllers) {
                    val metadata = controller.metadata ?: continue
                    val playbackState = controller.playbackState

                    // Only consider playing sessions
                    if (playbackState?.state != android.media.session.PlaybackState.STATE_PLAYING) continue

                    val title = metadata.getString(MediaMetadata.METADATA_KEY_TITLE)
                        ?: metadata.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
                    val artist = metadata.getString(MediaMetadata.METADATA_KEY_ARTIST)
                        ?: metadata.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)

                    if (title != null) {
                        _currentMediaTitle = title
                        _currentMediaArtist = artist
                        return
                    }
                }
            } catch (e: Exception) {
                Log.d(TAG, "Could not get media info: ${e.message}")
            }
        }

        private fun getAppLabel(context: Context, packageName: String): String {
            return try {
                val appInfo = context.packageManager.getApplicationInfo(packageName, 0)
                context.packageManager.getApplicationLabel(appInfo).toString()
            } catch (_: PackageManager.NameNotFoundException) {
                packageName
            }
        }
    }
}
