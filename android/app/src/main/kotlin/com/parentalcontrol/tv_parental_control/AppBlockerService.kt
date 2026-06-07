package com.parentalcontrol.tv_parental_control

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.SharedPreferences
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent

class AppBlockerService : AccessibilityService() {

    companion object {
        private const val PREFS_NAME = "app_blocker_prefs"
        private const val KEY_BLOCKED_APPS = "blocked_apps"
        private const val KEY_BLOCKING_ENABLED = "blocking_enabled"
        private const val KEY_ACTIVE_CHILD_ID = "active_child_id"
        private const val KEY_LAST_BLOCKED_APP = "last_blocked_app"
        private const val KEY_LAST_BLOCKED_LABEL = "last_blocked_label"
        private const val KEY_LAST_BLOCKED_TIME = "last_blocked_time"

        @Volatile
        var instance: AppBlockerService? = null
            private set

        fun isRunning(): Boolean = instance != null

        fun isAccessibilityEnabled(context: Context): Boolean {
            val serviceName = "${context.packageName}/${AppBlockerService::class.java.canonicalName}"
            val enabledServices = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            return enabledServices.contains(serviceName)
        }

        fun setBlockedApps(context: Context, childId: Int, packageNames: Set<String>) {
            getPrefs(context).edit()
                .putStringSet("${KEY_BLOCKED_APPS}_$childId", packageNames)
                .apply()
        }

        fun getBlockedApps(context: Context, childId: Int): Set<String> {
            return getPrefs(context).getStringSet("${KEY_BLOCKED_APPS}_$childId", emptySet()) ?: emptySet()
        }

        fun setActiveChild(context: Context, childId: Int) {
            getPrefs(context).edit()
                .putInt(KEY_ACTIVE_CHILD_ID, childId)
                .apply()
        }

        fun getActiveChild(context: Context): Int {
            return getPrefs(context).getInt(KEY_ACTIVE_CHILD_ID, -1)
        }

        fun setBlockingEnabled(context: Context, enabled: Boolean) {
            getPrefs(context).edit()
                .putBoolean(KEY_BLOCKING_ENABLED, enabled)
                .apply()
        }

        fun isBlockingEnabled(context: Context): Boolean {
            return getPrefs(context).getBoolean(KEY_BLOCKING_ENABLED, false)
        }

        fun setLastBlockedApp(context: Context, packageName: String, appLabel: String) {
            getPrefs(context).edit()
                .putString(KEY_LAST_BLOCKED_APP, packageName)
                .putString(KEY_LAST_BLOCKED_LABEL, appLabel)
                .putLong(KEY_LAST_BLOCKED_TIME, System.currentTimeMillis())
                .apply()
        }

        fun getLastBlockedEvent(context: Context): Map<String, Any>? {
            val prefs = getPrefs(context)
            val pkg = prefs.getString(KEY_LAST_BLOCKED_APP, null) ?: return null
            val label = prefs.getString(KEY_LAST_BLOCKED_LABEL, pkg) ?: pkg
            val time = prefs.getLong(KEY_LAST_BLOCKED_TIME, 0)
            return mapOf("packageName" to pkg, "appLabel" to label, "timestamp" to time)
        }

        fun clearLastBlockedEvent(context: Context) {
            getPrefs(context).edit()
                .remove(KEY_LAST_BLOCKED_APP)
                .remove(KEY_LAST_BLOCKED_LABEL)
                .remove(KEY_LAST_BLOCKED_TIME)
                .apply()
        }

        private fun getPrefs(context: Context): SharedPreferences {
            return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }
    }

    private var lastBlockedPackage: String? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        if (!isBlockingEnabled(this)) return

        val packageName = event.packageName?.toString() ?: return

        // Notify activity tracker of every foreground app change
        ActivityTracker.onAppChanged(this, packageName)

        // Don't block our own app or system UI
        if (packageName == this.packageName ||
            packageName == "com.android.systemui" ||
            packageName == "com.android.launcher" ||
            packageName.startsWith("com.android.launcher") ||
            packageName == "com.google.android.tvlauncher" ||
            packageName == "com.google.android.leanbacklauncher" ||
            packageName == "com.android.settings") {
            if (lastBlockedPackage != null) {
                AppBlockerOverlay.dismiss(this)
                lastBlockedPackage = null
            }
            return
        }

        val childId = getActiveChild(this)
        if (childId == -1) return

        val blockedApps = getBlockedApps(this, childId)

        if (blockedApps.contains(packageName)) {
            if (lastBlockedPackage != packageName) {
                lastBlockedPackage = packageName
                val appLabel = try {
                    val appInfo = packageManager.getApplicationInfo(packageName, 0)
                    packageManager.getApplicationLabel(appInfo).toString()
                } catch (_: Exception) {
                    packageName
                }
                AppBlockerOverlay.show(this, appLabel)
                setLastBlockedApp(this, packageName, appLabel)
            }
        } else {
            if (lastBlockedPackage != null) {
                AppBlockerOverlay.dismiss(this)
                lastBlockedPackage = null
            }
        }
    }

    override fun onInterrupt() {
        AppBlockerOverlay.dismiss(this)
        lastBlockedPackage = null
    }

    override fun onDestroy() {
        AppBlockerOverlay.dismiss(this)
        instance = null
        super.onDestroy()
    }
}
