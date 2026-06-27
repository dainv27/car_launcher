package com.carlauncher.car_launcher

import android.app.ActivityOptions
import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log

object MultiWindowLauncher {
    private const val TAG = "MultiWindowLauncher"
    private const val WINDOWING_MODE_FREEFORM = 5

    fun launchMapsWithYoutubeOnTop(context: Context): Boolean {
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
                    if (!launchYoutubeFreeform(context, youtubeIntent)) {
                        launchYoutubeAdjacent(context, youtubeIntent)
                    }
                },
                700,
            )
            true
        } catch (e: Exception) {
            Log.w(TAG, "Unable to launch Maps before YouTube", e)
            false
        }
    }

    private fun launchYoutubeFreeform(context: Context, intent: Intent): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false

        val metrics = context.resources.displayMetrics
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val windowWidth = (width * 0.38f).toInt().coerceAtLeast(480)
        val windowHeight = (height * 0.72f).toInt().coerceAtLeast(360)
        val margin = (16 * metrics.density).toInt()
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
