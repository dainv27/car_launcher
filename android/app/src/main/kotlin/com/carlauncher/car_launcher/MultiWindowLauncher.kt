package com.carlauncher.car_launcher

import android.app.ActivityOptions
import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Launches Maps full-screen with YouTube layered on top in a smaller window.
 *
 * Window sizing/timing (fractions, minimum pixel size, margin, stagger delay)
 * is a product/layout decision, not platform glue — the caller (Flutter)
 * supplies it via [WindowLayoutConfig]. This object only knows how to *ask*
 * the OS for a freeform window of the given bounds.
 */
data class WindowLayoutConfig(
    val widthFraction: Float = 0.38f,
    val heightFraction: Float = 0.72f,
    val marginDp: Float = 16f,
    val minWidthPx: Int = 480,
    val minHeightPx: Int = 360,
    val secondWindowDelayMs: Long = 700,
)

object MultiWindowLauncher {
    private const val TAG = "MultiWindowLauncher"
    private const val WINDOWING_MODE_FREEFORM = 5

    fun launchMapsWithYoutubeOnTop(context: Context, layout: WindowLayoutConfig = WindowLayoutConfig()): Boolean {
        val packageManager = context.packageManager
        val mapsIntent = packageManager.getLaunchIntentForPackage("com.google.android.apps.maps")
            ?: return false
        val youtubeIntent = packageManager.getLaunchIntentForPackage("com.google.android.youtube")
            ?: return false

        mapsIntent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_MULTIPLE_TASK or
                Intent.FLAG_ACTIVITY_NO_ANIMATION,
        )

        return try {
            context.startActivity(mapsIntent)
            Handler(Looper.getMainLooper()).postDelayed(
                {
                    if (!launchYoutubeFreeform(context, youtubeIntent, layout)) {
                        launchYoutubeAdjacent(context, youtubeIntent)
                    }
                },
                layout.secondWindowDelayMs,
            )
            true
        } catch (e: Exception) {
            Log.w(TAG, "Unable to launch Maps before YouTube", e)
            false
        }
    }

    private fun launchYoutubeFreeform(context: Context, intent: Intent, layout: WindowLayoutConfig): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false

        val metrics = context.resources.displayMetrics
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val windowWidth = (width * layout.widthFraction).toInt().coerceAtLeast(layout.minWidthPx)
        val windowHeight = (height * layout.heightFraction).toInt().coerceAtLeast(layout.minHeightPx)
        val margin = (layout.marginDp * metrics.density).toInt()
        val bounds = Rect(
            (width - windowWidth - margin).coerceAtLeast(0),
            margin,
            (width - margin).coerceAtLeast(windowWidth),
            (margin + windowHeight).coerceAtMost(height),
        )

        val options = ActivityOptions.makeBasic().apply {
            launchBounds = bounds
        }
        if (!enableFreeformWindowing(options)) return false

        val freeformIntent = Intent(intent).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_MULTIPLE_TASK or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION,
            )
        }

        return try {
            context.startActivity(freeformIntent, options.toBundle())
            Log.i(TAG, "Requested YouTube freeform window: $bounds")
            true
        } catch (e: Exception) {
            Log.w(TAG, "YouTube freeform launch failed", e)
            false
        }
    }

    private fun enableFreeformWindowing(options: ActivityOptions): Boolean {
        return try {
            val method = ActivityOptions::class.java.getMethod(
                "setLaunchWindowingMode",
                Int::class.javaPrimitiveType,
            )
            method.invoke(options, WINDOWING_MODE_FREEFORM)
            true
        } catch (e: Exception) {
            Log.d(TAG, "Freeform windowing mode API unavailable", e)
            false
        }
    }

    private fun launchYoutubeAdjacent(context: Context, intent: Intent): Boolean {
        val adjacentIntent = Intent(intent).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_LAUNCH_ADJACENT or
                    Intent.FLAG_ACTIVITY_MULTIPLE_TASK or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION,
            )
        }

        return try {
            context.startActivity(adjacentIntent)
            Log.i(TAG, "Requested YouTube adjacent window")
            true
        } catch (e: Exception) {
            Log.w(TAG, "YouTube adjacent launch failed", e)
            false
        }
    }
}
