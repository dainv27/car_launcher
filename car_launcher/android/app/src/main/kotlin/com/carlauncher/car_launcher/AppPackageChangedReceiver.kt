package com.carlauncher.car_launcher

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AppPackageChangedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val packageName = intent.data?.schemeSpecificPart ?: return
        val action = intent.action ?: return

        when (action) {
            Intent.ACTION_PACKAGE_ADDED,
            Intent.ACTION_PACKAGE_REMOVED,
            Intent.ACTION_PACKAGE_REPLACED -> Log.i(
                TAG,
                "Package change action=$action package=$packageName replacing=${intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)}",
            )
        }
    }

    private companion object {
        const val TAG = "AppPackageChangedReceiver"
    }
}
