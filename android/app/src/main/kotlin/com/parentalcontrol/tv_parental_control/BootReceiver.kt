package com.parentalcontrol.tv_parental_control

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // If a timer was running when device shut down, the service
            // will need to be restarted from the Flutter side on next app launch.
            // The foreground service with START_STICKY handles most cases.
        }
    }
}
