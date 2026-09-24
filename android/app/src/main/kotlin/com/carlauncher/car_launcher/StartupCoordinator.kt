package com.carlauncher.car_launcher

import android.app.job.JobInfo
import android.app.role.RoleManager
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.PersistableBundle
import android.os.UserManager
import android.util.Log

/**
 * Brings the launcher up after boot as soon as the user is unlocked.
 *
 * Only the user unlock is a hard requirement (MainActivity is not direct-boot
 * aware). The embedded Maps/YouTube packages get a short grace period and are
 * then left to [com.carlauncher.car_launcher.embedding.VirtualDisplayAppView],
 * which waits for its own readiness without failing the pane.
 */
object StartupCoordinator {
    const val EXTRA_ATTEMPT = "attempt"
    const val EXTRA_LAUNCH = "launch"
    const val INITIAL_BOOT_DELAY_MS = 1_000L
    const val PACKAGE_REPLACED_DELAY_MS = 1_000L
    const val RETRY_DELAY_MS = 1_000L

    // ~1 minute of unlock polling. BOOT_COMPLETED is only sent after unlock
    // and schedules a fresh check, so giving up here never strands the car.
    const val MAX_ATTEMPTS = 60

    // Launch without the embedded packages after ~3s instead of blocking the
    // whole launcher on them.
    const val PACKAGE_GRACE_ATTEMPTS = 3

    // JobScheduler clamps backoff to at least 10s (JobInfo.MIN_BACKOFF_MILLIS, hidden).
    private const val MIN_JOB_BACKOFF_MS = 10_000L

    private const val TAG = "StartupCoordinator"
    private const val STARTUP_JOB_ID = 4107

    private val requiredLaunchablePackages = setOf(
        "com.google.android.apps.maps",
        "com.google.android.youtube",
    )

    /**
     * [launch]=false only restores the Home preference (see
     * [restoreHomePreferenceIfNeeded]) without bringing the launcher up.
     */
    fun scheduleStartupCheck(
        context: Context,
        attempt: Int,
        delayMs: Long,
        launch: Boolean = true,
    ) {
        val scheduler = context.getSystemService(JobScheduler::class.java) ?: return
        val jobInfo = JobInfo.Builder(
            STARTUP_JOB_ID,
            ComponentName(context, StartupJobService::class.java),
        )
            .setMinimumLatency(delayMs)
            .setOverrideDeadline(delayMs + RETRY_DELAY_MS)
            // A crash-recovery job can bind to the still-dying process
            // ("binding died"); retry at the minimum backoff instead of the
            // 30s exponential default, which kept Home unresolved ~47s.
            .setBackoffCriteria(MIN_JOB_BACKOFF_MS, JobInfo.BACKOFF_POLICY_LINEAR)
            .setExtras(
                PersistableBundle().apply {
                    putInt(EXTRA_ATTEMPT, attempt)
                    putBoolean(EXTRA_LAUNCH, launch)
                },
            )
            .build()

        val result = scheduler.schedule(jobInfo)
        Log.i(TAG, "Scheduled startup job attempt=$attempt delayMs=$delayMs launch=$launch result=$result")
    }

    /**
     * Re-selects this launcher as the preferred Home activity while it still
     * holds the Home role.
     *
     * AOSP clears the Home preference every time a non-FLAG_SYSTEM Home app
     * crashes (AppErrors.handleAppCrashLocked). The role survives, but with
     * Launcher3 also installed Home resolves ambiguously and this ROM parks
     * the head unit on Settings' FallbackHome ("… is starting") for good.
     * If the user deliberately picked another Home app we no longer hold the
     * role and leave their choice alone.
     */
    fun restoreHomePreferenceIfNeeded(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val roleManager = context.getSystemService(RoleManager::class.java)
        if (roleManager?.isRoleHeld(RoleManager.ROLE_HOME) != true) return

        val packageManager = context.packageManager
        val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val resolved = packageManager.resolveActivity(homeIntent, PackageManager.MATCH_DEFAULT_ONLY)
        if (resolved?.activityInfo?.packageName == context.packageName) return

        val homeActivities = packageManager
            .queryIntentActivities(homeIntent, PackageManager.MATCH_DEFAULT_ONLY)
            .map { ComponentName(it.activityInfo.packageName, it.activityInfo.name) }
        val filter = IntentFilter(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            addCategory(Intent.CATEGORY_DEFAULT)
        }
        try {
            // Deprecated for normal apps; honoured for the system uid, which
            // holds SET_PREFERRED_APPLICATIONS.
            @Suppress("DEPRECATION")
            packageManager.addPreferredActivity(
                filter,
                IntentFilter.MATCH_CATEGORY_EMPTY,
                homeActivities.toTypedArray(),
                ComponentName(context, MainActivity::class.java),
            )
            Log.i(TAG, "Restored Home preference (was ${resolved?.activityInfo?.packageName})")
        } catch (error: Throwable) {
            Log.w(TAG, "Unable to restore Home preference", error)
        }
    }

    fun readStartupReadiness(context: Context): StartupReadiness {
        val userManager = context.getSystemService(UserManager::class.java)
        if (userManager?.isUserUnlocked != true) {
            return StartupReadiness(false, false, "user locked")
        }

        val missingPackages = requiredLaunchablePackages.filterNot { packageName ->
            isPackageLaunchable(context, packageName)
        }
        if (missingPackages.isNotEmpty()) {
            return StartupReadiness(
                false,
                true,
                "missing launchable packages: ${missingPackages.joinToString()}",
            )
        }

        return StartupReadiness(true, true, "user unlocked and dashboard packages launchable")
    }

    /**
     * True when the launcher activity already exists (e.g. Android started it
     * as the default Home app). Re-launching would only yank the driver back
     * from whatever they opened meanwhile.
     */
    fun isLauncherAlreadyRunning(): Boolean = MainActivity.instance != null

    fun launchMainActivity(context: Context) {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION,
            )
        }
        try {
            context.startActivity(launchIntent)
            Log.i(TAG, "Requested MainActivity startup after boot readiness")
        } catch (error: Throwable) {
            Log.w(TAG, "Unable to start MainActivity after boot", error)
        }
    }

    private fun isPackageLaunchable(context: Context, packageName: String): Boolean {
        return try {
            val appInfo = context.packageManager.getApplicationInfo(packageName, 0)
            appInfo.enabled && context.packageManager.getLaunchIntentForPackage(packageName) != null
        } catch (_: PackageManager.NameNotFoundException) {
            false
        } catch (error: Throwable) {
            Log.w(TAG, "Unable to inspect package=$packageName", error)
            false
        }
    }

    /**
     * [ready]: everything the dashboard wants is available.
     * [userUnlocked]: the hard requirement for starting MainActivity.
     */
    data class StartupReadiness(
        val ready: Boolean,
        val userUnlocked: Boolean,
        val reason: String,
    )
}
