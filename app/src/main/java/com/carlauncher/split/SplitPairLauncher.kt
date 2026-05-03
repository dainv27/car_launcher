package com.carlauncher.split

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import com.carlauncher.R
import com.carlauncher.home.AppEntry

/**
 * Cố gắng mở hai ứng dụng ở chế độ **chia đôi màn hình** (multi-window) do hệ thống vẽ.
 * App thường **không thể** nhúng giao diện hai app khác trong cùng một Activity.
 */
object SplitPairLauncher {

    private const val FLAG_BASE =
        Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_MULTIPLE_TASK

    fun launch(context: Context, first: AppEntry, second: AppEntry): Boolean =
        tryLaunch(context, first.component, second.component)

    fun launch(context: Context, first: ComponentName, second: ComponentName): Boolean =
        tryLaunch(context, first, second)

    private fun tryLaunch(context: Context, first: ComponentName, second: ComponentName): Boolean {
        val appContext = context.applicationContext
        val primary = intentFor(first, includeAdjacent = false)
        val secondary = intentFor(second, includeAdjacent = true)

        return try {
            appContext.startActivities(arrayOf(primary, secondary))
            true
        } catch (_: Exception) {
            trySequentialFallback(appContext, first, second)
        }
    }

    private fun intentFor(component: ComponentName, includeAdjacent: Boolean): Intent =
        Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
            this.component = component
            addFlags(
                if (includeAdjacent) {
                    FLAG_BASE or Intent.FLAG_ACTIVITY_LAUNCH_ADJACENT
                } else {
                    FLAG_BASE
                },
            )
        }

    private fun trySequentialFallback(
        appContext: Context,
        first: ComponentName,
        second: ComponentName,
    ): Boolean {
        return try {
            appContext.startActivity(intentFor(first, includeAdjacent = false))
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    appContext.startActivity(intentFor(second, includeAdjacent = true))
                } catch (_: Exception) {
                    toastFail(appContext)
                }
            }, 420)
            true
        } catch (_: Exception) {
            toastFail(appContext)
            false
        }
    }

    private fun toastFail(appContext: Context) {
        Toast.makeText(
            appContext,
            appContext.getString(R.string.split_failed_toast),
            Toast.LENGTH_LONG,
        ).show()
    }
}
