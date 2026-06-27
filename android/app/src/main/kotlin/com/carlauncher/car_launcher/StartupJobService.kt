package com.carlauncher.car_launcher

import android.app.job.JobParameters
import android.app.job.JobService
import android.util.Log

class StartupJobService : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        val attempt = params.extras.getInt(StartupCoordinator.EXTRA_ATTEMPT, 1)
        val readiness = StartupCoordinator.readStartupReadiness(this)

        if (readiness.ready || attempt >= StartupCoordinator.MAX_ATTEMPTS) {
            if (readiness.ready) {
                Log.i(TAG, "Startup dependencies ready: ${readiness.reason}")
            } else {
                Log.w(TAG, "Launching after max attempts despite: ${readiness.reason}")
            }
            StartupCoordinator.launchMainActivity(this)
            jobFinished(params, false)
            return false
        }

        Log.i(TAG, "Startup dependencies not ready: ${readiness.reason}; retry=$attempt")
        StartupCoordinator.scheduleStartupCheck(
            context = this,
            attempt = attempt + 1,
            delayMs = StartupCoordinator.RETRY_DELAY_MS,
        )
        jobFinished(params, false)
        return false
    }

    override fun onStopJob(params: JobParameters): Boolean = true

    private companion object {
        const val TAG = "StartupJobService"
    }
}
