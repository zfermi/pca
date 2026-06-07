package com.parentalcontrol.tv_parental_control

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.view.Gravity
import android.view.WindowManager
import android.widget.*
import android.view.View
import java.security.MessageDigest

object OverlayLockScreen {

    private var overlayView: View? = null
    private var windowManager: WindowManager? = null

    fun show(context: Context, storedPinHash: String) {
        if (overlayView != null) return

        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

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
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.CENTER

        val rootLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#D32F2F"))
            setPadding(64, 64, 64, 64)
        }

        // Clock icon using text emoji (no drawable dependency)
        val iconText = TextView(context).apply {
            text = "⏰"
            textSize = 64f
            gravity = Gravity.CENTER
        }
        rootLayout.addView(iconText)

        val titleText = TextView(context).apply {
            text = "Time's Up!"
            textSize = 36f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 32, 0, 16)
        }
        rootLayout.addView(titleText)

        val subtitleText = TextView(context).apply {
            text = "Your TV time has ended.\nAsk a parent to unlock."
            textSize = 18f
            setTextColor(Color.parseColor("#FFCDD2"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 48)
        }
        rootLayout.addView(subtitleText)

        val pinInput = EditText(context).apply {
            hint = "Enter parent PIN"
            setHintTextColor(Color.parseColor("#999999"))
            setTextColor(Color.BLACK)
            textSize = 20f
            setBackgroundColor(Color.WHITE)
            setPadding(32, 24, 32, 24)
            inputType = android.text.InputType.TYPE_CLASS_NUMBER or
                android.text.InputType.TYPE_NUMBER_VARIATION_PASSWORD
            gravity = Gravity.CENTER
            maxLines = 1
        }
        val pinParams = LinearLayout.LayoutParams(600, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.CENTER
            bottomMargin = 24
        }
        rootLayout.addView(pinInput, pinParams)

        val errorText = TextView(context).apply {
            text = ""
            textSize = 14f
            setTextColor(Color.parseColor("#FFCDD2"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 24)
        }
        rootLayout.addView(errorText)

        val unlockButton = Button(context).apply {
            text = "UNLOCK"
            textSize = 18f
            setTextColor(Color.parseColor("#D32F2F"))
            setBackgroundColor(Color.WHITE)
            setPadding(48, 16, 48, 16)

            setOnClickListener {
                val enteredPin = pinInput.text.toString()
                if (enteredPin.isEmpty()) {
                    errorText.text = "Please enter a PIN"
                    return@setOnClickListener
                }

                val enteredHash = hashPin(enteredPin)
                if (enteredHash == storedPinHash) {
                    dismiss(context)
                    // Stop the timer service
                    val stopIntent = android.content.Intent(context, TimerService::class.java).apply {
                        action = TimerService.ACTION_STOP
                    }
                    context.startService(stopIntent)
                } else {
                    errorText.text = "Incorrect PIN. Try again."
                    pinInput.text.clear()
                }
            }
        }
        val btnParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
        }
        rootLayout.addView(unlockButton, btnParams)

        // Make the overlay focusable so the keyboard works for PIN entry
        params.flags = WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS

        overlayView = rootLayout

        try {
            windowManager?.addView(overlayView, params)
        } catch (e: Exception) {
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

    private fun hashPin(pin: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val hash = digest.digest(pin.toByteArray())
        return hash.joinToString("") { "%02x".format(it) }
    }
}
