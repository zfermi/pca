package com.parentalcontrol.tv_parental_control

import android.app.admin.DevicePolicyManager
import android.app.UiModeManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.os.UserManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.parentalcontrol.tvpca/timer"
        const val OVERLAY_PERMISSION_REQUEST = 1001
    }

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTimer" -> {
                    val childId = call.argument<Int>("childId") ?: -1
                    val childName = call.argument<String>("childName") ?: ""
                    val minutes = call.argument<Int>("minutes") ?: 0
                    val pinHash = call.argument<String>("pinHash") ?: ""

                    val intent = Intent(this, TimerService::class.java).apply {
                        action = TimerService.ACTION_START
                        putExtra(TimerService.EXTRA_CHILD_ID, childId)
                        putExtra(TimerService.EXTRA_CHILD_NAME, childName)
                        putExtra(TimerService.EXTRA_MINUTES, minutes)
                        putExtra(TimerService.EXTRA_PIN_HASH, pinHash)
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }

                "stopTimer" -> {
                    val intent = Intent(this, TimerService::class.java).apply {
                        action = TimerService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(true)
                }

                "addBonusTime" -> {
                    val minutes = call.argument<Int>("minutes") ?: 0
                    val intent = Intent(this, TimerService::class.java).apply {
                        action = TimerService.ACTION_ADD_TIME
                        putExtra(TimerService.EXTRA_MINUTES, minutes)
                    }
                    startService(intent)
                    result.success(true)
                }

                "getTimerState" -> {
                    result.success(mapOf(
                        "isRunning" to TimerService.isRunning,
                        "remainingSeconds" to TimerService.remainingSeconds,
                        "totalSeconds" to TimerService.totalSeconds,
                        "childId" to TimerService.activeChildId,
                        "childName" to TimerService.activeChildName
                    ))
                }

                "hasOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }

                "isTvDevice" -> {
                    result.success(isTvDevice())
                }

                "getDeviceProtectionState" -> {
                    result.success(getDeviceProtectionState())
                }

                "requestDeviceAdmin" -> {
                    result.success(requestDeviceAdmin())
                }

                "setDeviceProtectionEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    result.success(setDeviceProtectionEnabled(enabled))
                }

                "startKioskMode" -> {
                    result.success(startKioskMode())
                }

                "stopKioskMode" -> {
                    result.success(stopKioskMode())
                }

                "requestOverlayPermission" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        pendingResult = result
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST)
                    } else {
                        result.success(true)
                    }
                }

                "dismissOverlay" -> {
                    OverlayLockScreen.dismiss(this)
                    result.success(true)
                }

                "getInstalledApps" -> {
                    result.success(getInstalledApps())
                }

                "setBlockedApps" -> {
                    val childId = call.argument<Int>("childId") ?: -1
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    AppBlockerService.setBlockedApps(this, childId, packages.toSet())
                    result.success(true)
                }

                "getBlockedApps" -> {
                    val childId = call.argument<Int>("childId") ?: -1
                    result.success(AppBlockerService.getBlockedApps(this, childId).toList())
                }

                "setActiveChildForBlocking" -> {
                    val childId = call.argument<Int>("childId") ?: -1
                    AppBlockerService.setActiveChild(this, childId)
                    result.success(true)
                }

                "setBlockingEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    AppBlockerService.setBlockingEnabled(this, enabled)
                    result.success(true)
                }

                "isBlockingEnabled" -> {
                    result.success(AppBlockerService.isBlockingEnabled(this))
                }

                "isAccessibilityEnabled" -> {
                    result.success(AppBlockerService.isAccessibilityEnabled(this))
                }

                "requestAccessibilityPermission" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }

                "dismissBlockerOverlay" -> {
                    AppBlockerOverlay.dismiss(this)
                    result.success(true)
                }

                "startActivityTracking" -> {
                    ActivityTracker.startTracking()
                    result.success(true)
                }

                "stopActivityTracking" -> {
                    ActivityTracker.stopTracking()
                    result.success(true)
                }

                "getCurrentActivity" -> {
                    val activity = ActivityTracker.getCurrentActivity()
                    result.success(activity)
                }

                "getActivityHistory" -> {
                    val limit = call.argument<Int>("limit") ?: 20
                    result.success(ActivityTracker.getActivityHistory(limit))
                }

                "getNewActivities" -> {
                    val sinceTimestamp = call.argument<Long>("sinceTimestamp") ?: 0L
                    result.success(ActivityTracker.getNewActivities(sinceTimestamp))
                }

                "updateMediaInfo" -> {
                    ActivityTracker.updateMediaInfo(this)
                    result.success(ActivityTracker.getCurrentActivity())
                }

                "getLastBlockedEvent" -> {
                    result.success(AppBlockerService.getLastBlockedEvent(this))
                }

                "clearLastBlockedEvent" -> {
                    AppBlockerService.clearLastBlockedEvent(this)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun getInstalledApps(): List<Map<String, Any?>> {
        val apps = mutableListOf<Map<String, Any?>>()
        val packages = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)

        for (appInfo in packages) {
            // Skip system apps that aren't updated, and skip our own app
            if (appInfo.packageName == packageName) continue
            if (appInfo.flags and ApplicationInfo.FLAG_SYSTEM != 0 &&
                appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP == 0) {
                // Include some well-known system apps users might want to block
                val includedSystemApps = setOf(
                    "com.google.android.youtube",
                    "com.google.android.youtube.tv",
                    "com.google.android.apps.youtube.kids",
                    "com.android.chrome",
                    "com.google.android.videos",
                    "com.google.android.apps.tv.launcherx"
                )
                if (!includedSystemApps.contains(appInfo.packageName)) continue
            }

            val label = packageManager.getApplicationLabel(appInfo).toString()
            var iconBytes: ByteArray? = null
            try {
                val drawable = packageManager.getApplicationIcon(appInfo)
                val bitmap = if (drawable is BitmapDrawable) {
                    drawable.bitmap
                } else {
                    val bmp = Bitmap.createBitmap(48, 48, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bmp)
                    drawable.setBounds(0, 0, 48, 48)
                    drawable.draw(canvas)
                    bmp
                }
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 80, stream)
                iconBytes = stream.toByteArray()
            } catch (_: Exception) {}

            apps.add(mapOf(
                "packageName" to appInfo.packageName,
                "appLabel" to label,
                "icon" to iconBytes
            ))
        }

        apps.sortBy { (it["appLabel"] as? String)?.lowercase() }
        return apps
    }

    private fun isTvDevice(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        val isTelevisionMode =
            uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
        val hasLeanback = packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
        val hasTelevision = packageManager.hasSystemFeature(PackageManager.FEATURE_TELEVISION)
        return isTelevisionMode || hasLeanback || hasTelevision
    }

    private fun adminComponent(): ComponentName {
        return ComponentName(this, TvpcaDeviceAdminReceiver::class.java)
    }

    private fun devicePolicyManager(): DevicePolicyManager {
        return getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    }

    private fun getDeviceProtectionState(): Map<String, Any?> {
        val dpm = devicePolicyManager()
        val admin = adminComponent()
        val isAdminActive = dpm.isAdminActive(admin)
        val isDeviceOwner = dpm.isDeviceOwnerApp(packageName)
        val supportsDeviceAdmin = packageManager.hasSystemFeature(PackageManager.FEATURE_DEVICE_ADMIN)
        val uninstallBlocked = try {
            dpm.isUninstallBlocked(null, packageName)
        } catch (_: Exception) {
            false
        }
        val lockTaskPermitted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            dpm.isLockTaskPermitted(packageName)
        } else {
            false
        }
        val appsControlRestricted = try {
            dpm.getUserRestrictions(admin)
                .getBoolean(UserManager.DISALLOW_APPS_CONTROL, false)
        } catch (_: Exception) {
            false
        }

        return mapOf(
            "isAdminActive" to isAdminActive,
            "isDeviceOwner" to isDeviceOwner,
            "supportsDeviceAdmin" to supportsDeviceAdmin,
            "uninstallBlocked" to uninstallBlocked,
            "lockTaskPermitted" to lockTaskPermitted,
            "appsControlRestricted" to appsControlRestricted,
            "packageName" to packageName,
            "adminReceiver" to "$packageName/.TvpcaDeviceAdminReceiver",
            "provisioningCommand" to "adb shell dpm set-device-owner $packageName/.TvpcaDeviceAdminReceiver"
        )
    }

    private fun requestDeviceAdmin(): Map<String, Any?> {
        return try {
            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent())
                putExtra(
                    DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                    "Activate protection so TV Parental Control is harder to remove."
                )
            }
            startActivity(intent)
            getDeviceProtectionState() + mapOf(
                "success" to true,
                "message" to "Device admin setup opened."
            )
        } catch (e: Exception) {
            getDeviceProtectionState() + mapOf(
                "success" to false,
                "message" to (e.message ?: "Unable to open device admin setup.")
            )
        }
    }

    private fun setDeviceProtectionEnabled(enabled: Boolean): Map<String, Any?> {
        val dpm = devicePolicyManager()
        val admin = adminComponent()

        if (!dpm.isDeviceOwnerApp(packageName)) {
            return getDeviceProtectionState() + mapOf(
                "success" to false,
                "message" to "TV Parental Control is not the Device Owner."
            )
        }

        return try {
            dpm.setUninstallBlocked(admin, packageName, enabled)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                dpm.setLockTaskPackages(
                    admin,
                    if (enabled) arrayOf(packageName) else emptyArray()
                )
            }
            if (enabled) {
                dpm.addUserRestriction(admin, UserManager.DISALLOW_APPS_CONTROL)
                dpm.addUserRestriction(admin, UserManager.DISALLOW_SAFE_BOOT)
            } else {
                dpm.clearUserRestriction(admin, UserManager.DISALLOW_APPS_CONTROL)
                dpm.clearUserRestriction(admin, UserManager.DISALLOW_SAFE_BOOT)
            }

            getDeviceProtectionState() + mapOf(
                "success" to true,
                "message" to if (enabled) {
                    "Device protection enabled."
                } else {
                    "Device protection disabled."
                }
            )
        } catch (e: Exception) {
            getDeviceProtectionState() + mapOf(
                "success" to false,
                "message" to (e.message ?: "Unable to update device protection.")
            )
        }
    }

    private fun startKioskMode(): Map<String, Any?> {
        val dpm = devicePolicyManager()
        if (!dpm.isLockTaskPermitted(packageName)) {
            return getDeviceProtectionState() + mapOf(
                "success" to false,
                "message" to "Kiosk mode is not allowlisted for this app."
            )
        }

        return try {
            startLockTask()
            getDeviceProtectionState() + mapOf(
                "success" to true,
                "message" to "Kiosk mode started."
            )
        } catch (e: Exception) {
            getDeviceProtectionState() + mapOf(
                "success" to false,
                "message" to (e.message ?: "Unable to start kiosk mode.")
            )
        }
    }

    private fun stopKioskMode(): Map<String, Any?> {
        return try {
            stopLockTask()
            getDeviceProtectionState() + mapOf(
                "success" to true,
                "message" to "Kiosk mode stopped."
            )
        } catch (e: Exception) {
            getDeviceProtectionState() + mapOf(
                "success" to false,
                "message" to (e.message ?: "Unable to stop kiosk mode.")
            )
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OVERLAY_PERMISSION_REQUEST) {
            pendingResult?.success(Settings.canDrawOverlays(this))
            pendingResult = null
        }
    }
}
