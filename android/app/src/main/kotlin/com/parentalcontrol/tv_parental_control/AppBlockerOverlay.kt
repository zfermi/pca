package com.parentalcontrol.tv_parental_control

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

object AppBlockerOverlay {

    private var overlayView: View? = null

    fun show(context: Context, appLabel: String) {
        if (overlayView != null) return

        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.CENTER

        val rootLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#1A1A2E"))
            setPadding(64, 64, 64, 64)
            isFocusable = true
            isFocusableInTouchMode = true

            setOnKeyListener { _, keyCode, event ->
                if (event.action == KeyEvent.ACTION_DOWN &&
                    (keyCode == KeyEvent.KEYCODE_BACK || keyCode == KeyEvent.KEYCODE_ESCAPE)) {
                    dismiss(context)
                    true
                } else {
                    false
                }
            }
        }

        val iconText = TextView(context).apply {
            text = "🚫"
            textSize = 72f
            gravity = Gravity.CENTER
        }
        rootLayout.addView(iconText)

        val titleText = TextView(context).apply {
            text = "App Blocked"
            textSize = 36f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 32, 0, 16)
        }
        rootLayout.addView(titleText)

        val appNameText = TextView(context).apply {
            text = appLabel
            textSize = 22f
            setTextColor(Color.parseColor("#6C63FF"))
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 16)
        }
        rootLayout.addView(appNameText)

        val subtitleText = TextView(context).apply {
            text = "This app has been blocked by your parent.\nPress BACK to return."
            textSize = 18f
            setTextColor(Color.parseColor("#AAAAAA"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 48)
        }
        rootLayout.addView(subtitleText)

        overlayView = rootLayout

        try {
            wm.addView(overlayView, params)
            rootLayout.requestFocus()
        } catch (_: Exception) {
            overlayView = null
        }
    }

    fun dismiss(context: Context) {
        overlayView?.let {
            try {
                val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                wm.removeView(it)
            } catch (_: Exception) {}
            overlayView = null
        }
    }

    fun isShowing(): Boolean = overlayView != null
}
