package com.carlauncher.car_launcher

import android.app.job.JobParameters
import android.app.job.JobService
import android.util.Log

class StartupJobService : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        val attempt = params.extras.getInt(StartupCoordinator.EXTRA_ATTEMPT, 1)
        val launch = params.extras.getBoolean(StartupCoordinator.EXTRA_LAUNCH, true)

        StartupCoordinator.restoreHomePreferenceIfNeeded(this)
        if (!launch) {
            jobFinished(params, false)
            return false
        }

        if (StartupCoordinator.isLauncherAlreadyRunning()) {
            Log.i(TAG, "Launcher already running; skipping boot launch")
            jobFinished(params, false)
            return false
        }

        val readiness = StartupCoordinator.readStartupReadiness(this)
        val packagesGraceOver = attempt >= StartupCoordinator.PACKAGE_GRACE_ATTEMPTS
        when {
            readiness.ready -> {
                Log.i(TAG, "Startup dependencies ready: ${readiness.reason}")
                StartupCoordinator.launchMainActivity(this)
            }
            readiness.userUnlocked && packagesGraceOver -> {
                // Embedded panes wait for their own packages; don't hold the
                // whole launcher back for them.
                Log.w(TAG, "Launching without optional dependencies: ${readiness.reason}")
                StartupCoordinator.launchMainActivity(this)
            }
            attempt >= StartupCoordinator.MAX_ATTEMPTS -> {
                // Still locked: MainActivity can't start yet. BOOT_COMPLETED
                // arrives on unlock and schedules a new check.
                Log.w(TAG, "Giving up boot launch while ${readiness.reason}")
            }
            else -> {
                Log.i(TAG, "Startup dependencies not ready: ${readiness.reason}; retry=$attempt")
                StartupCoordinator.scheduleStartupCheck(
                    context = this,
                    attempt = attempt + 1,
                    delayMs = StartupCoordinator.RETRY_DELAY_MS,
                )
            }
        }
        jobFinished(params, false)
        return false
    }

    override fun onStopJob(params: JobParameters): Boolean = true

    private companion object {
        const val TAG = "StartupJobService"
    }
}
