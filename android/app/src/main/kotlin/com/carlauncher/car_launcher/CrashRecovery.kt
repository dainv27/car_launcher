package com.carlauncher.car_launcher

import android.content.Context
import android.os.SystemClock
import android.util.Log

/**
 * Recovers the launcher after its process crashes.
 *
 * Every crash makes AOSP drop this app as the preferred Home, and a crash
 * while on screen can leave the driver on whatever app sat underneath. The
 * startup job lives in JobScheduler, so it survives the dying process: it
 * restarts the process, restores the Home preference and — only when the
 * launcher was visible — relaunches MainActivity through [StartupJobService].
 *
 * Crash loops stop being relaunched after [MAX_RECOVERIES_PER_WINDOW] crashes
 * within [RECOVERY_WINDOW_MS]; the Home preference is still restored, so the
 * next Home press brings the launcher up.
 */
object CrashRecovery {
    private const val TAG = "CrashRecovery"
    private const val PREFS_NAME = "crash_recovery"
    private const val KEY_RECENT_CRASHES = "recent_crash_elapsed_ms"
    private const val RECOVERY_DELAY_MS = 1_000L
    private const val RECOVERY_WINDOW_MS = 60_000L
    private const val MAX_RECOVERIES_PER_WINDOW = 3

    @Volatile
    private var installed = false

    /**
     * True while MainActivity is visible. A crash while the driver is in
     * another app must not yank them back to the launcher.
     */
    @Volatile
    var launcherVisible = false

    fun install(context: Context) {
        if (installed) return
        installed = true
        val appContext = context.applicationContext
        val previousHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                scheduleRecoveryIfNeeded(appContext)
            } catch (recoveryError: Throwable) {
                Log.w(TAG, "Unable to schedule crash recovery", recoveryError)
            }
            previousHandler?.uncaughtException(thread, error)
        }
    }

    private fun scheduleRecoveryIfNeeded(context: Context) {
        if (!launcherVisible) {
            Log.i(TAG, "Launcher not visible at crash time; restoring Home preference only")
            scheduleHomePreferenceRestore(context)
            return
        }
        // elapsedRealtime survives the process and resets on reboot, which is
        // exactly the lifetime a crash-loop window needs.
        val now = SystemClock.elapsedRealtime()
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val recentCrashes = prefs.getString(KEY_RECENT_CRASHES, "")
            .orEmpty()
            .split(',')
            .mapNotNull { it.toLongOrNull() }
            .filter { it in (now - RECOVERY_WINDOW_MS)..now }
        if (recentCrashes.size >= MAX_RECOVERIES_PER_WINDOW) {
            Log.w(TAG, "Crash loop detected (${recentCrashes.size} in window); not relaunching")
            scheduleHomePreferenceRestore(context)
            return
        }
        // commit(): the process is about to die, apply() may never flush.
        prefs.edit()
            .putString(KEY_RECENT_CRASHES, (recentCrashes + now).joinToString(","))
            .commit()
        // Start past the package grace period: the embedded panes wait for
        // their own packages, the launcher itself should come back at once.
        StartupCoordinator.scheduleStartupCheck(
            context = context,
            attempt = StartupCoordinator.PACKAGE_GRACE_ATTEMPTS,
            delayMs = RECOVERY_DELAY_MS,
        )
    }

    private fun scheduleHomePreferenceRestore(context: Context) {
        StartupCoordinator.scheduleStartupCheck(
            context = context,
            attempt = 1,
            delayMs = RECOVERY_DELAY_MS,
            launch = false,
        )
    }
}
