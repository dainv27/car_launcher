package com.carlauncher.car_launcher

import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.PersistableBundle
import android.os.UserManager
import android.util.Log

object StartupCoordinator {
    const val EXTRA_ATTEMPT = "attempt"
    const val INITIAL_BOOT_DELAY_MS = 10_000L
    const val PACKAGE_REPLACED_DELAY_MS = 3_000L
    const val RETRY_DELAY_MS = 5_000L
    const val MAX_ATTEMPTS = 10

    private const val TAG = "StartupCoordinator"
    private const val STARTUP_JOB_ID = 4107

    private val requiredLaunchablePackages = setOf(
        "com.google.android.apps.maps",
        "com.google.android.youtube",
    )

    fun scheduleStartupCheck(context: Context, attempt: Int, delayMs: Long) {
        val scheduler = context.getSystemService(JobScheduler::class.java) ?: return
        val jobInfo = JobInfo.Builder(
            STARTUP_JOB_ID,
            ComponentName(context, StartupJobService::class.java),
        )
            .setMinimumLatency(delayMs)
            .setOverrideDeadline(delayMs + RETRY_DELAY_MS)
            .setExtras(
                PersistableBundle().apply {
                    putInt(EXTRA_ATTEMPT, attempt)
                },
            )
            .build()

        val result = scheduler.schedule(jobInfo)
        Log.i(TAG, "Scheduled startup job attempt=$attempt delayMs=$delayMs result=$result")
    }

    fun readStartupReadiness(context: Context): StartupReadiness {
        val userManager = context.getSystemService(UserManager::class.java)
        if (userManager?.isUserUnlocked != true) {
            return StartupReadiness(false, "user locked")
        }

        val missingPackages = requiredLaunchablePackages.filterNot { packageName ->
            isPackageLaunchable(context, packageName)
        }
        if (missingPackages.isNotEmpty()) {
            return StartupReadiness(false, "missing launchable packages: ${missingPackages.joinToString()}")
        }

        return StartupReadiness(true, "user unlocked and dashboard packages launchable")
    }

    fun launchMainActivity(context: Context) {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION,
            )
        }
        context.startActivity(launchIntent)
        Log.i(TAG, "Requested MainActivity startup after boot readiness")
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

    data class StartupReadiness(val ready: Boolean, val reason: String)
}
