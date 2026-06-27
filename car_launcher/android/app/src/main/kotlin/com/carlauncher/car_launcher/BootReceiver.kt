package com.carlauncher.car_launcher

import android.content.Context
import android.content.BroadcastReceiver
import android.content.Intent
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.i(TAG, "Received action=$action")

        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> {
                StartupCoordinator.scheduleStartupCheck(
                    context = context,
                    attempt = 1,
                    delayMs = if (action == Intent.ACTION_MY_PACKAGE_REPLACED) {
                        StartupCoordinator.PACKAGE_REPLACED_DELAY_MS
                    } else {
                        StartupCoordinator.INITIAL_BOOT_DELAY_MS
                    },
                )
                startVehicleTrackingIfEnabled(context)
            }
        }
    }

    private fun startVehicleTrackingIfEnabled(context: Context) {
        val enabled = context
            .getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_ENABLED, false)
        if (!enabled) return

        val service = Intent(context, VehicleTrackingService::class.java).apply {
            action = VehicleTrackingService.ACTION_START
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(service)
            } else {
                context.startService(service)
            }
        } catch (error: Throwable) {
            Log.w(TAG, "Unable to restart vehicle tracking service", error)
        }
    }

    private companion object {
        const val TAG = "BootReceiver"
        const val FLUTTER_PREFS = "FlutterSharedPreferences"
        const val KEY_ENABLED = "flutter.vehicle_tracking_enabled"
    }
}