package com.carlauncher.car_launcher.embedding

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

object VirtualDisplayEmbeddingCapability {
    private const val FEATURE_ACTIVITIES_ON_SECONDARY_DISPLAYS =
        "android.software.activities_on_secondary_displays"
    private const val ADD_TRUSTED_DISPLAY = "android.permission.ADD_TRUSTED_DISPLAY"
    private const val INJECT_EVENTS = "android.permission.INJECT_EVENTS"

    data class SupportInfo(
        val supported: Boolean,
        val reason: String,
    )

    fun getSupportInfo(context: Context): SupportInfo {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return SupportInfo(false, "VirtualDisplay embedding requires Android 10+")
        }

        if (!context.packageManager.hasSystemFeature(FEATURE_ACTIVITIES_ON_SECONDARY_DISPLAYS)) {
            return SupportInfo(false, "ROM does not advertise secondary-display activities")
        }

        val missingPermissions = listOf(ADD_TRUSTED_DISPLAY).filter { permission ->
            context.checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED
        }

        if (missingPermissions.isNotEmpty()) {
            return SupportInfo(
                false,
                "Privileged/platform-signed installation required: ${missingPermissions.joinToString()}",
            )
        }

        val hasDirectInput =
            context.checkSelfPermission(INJECT_EVENTS) == PackageManager.PERMISSION_GRANTED
        val inputMode = when {
            hasDirectInput -> "direct INJECT_EVENTS input"
            EmbeddedInputAccessibilityService.isReady() -> "AccessibilityService input fallback"
            else -> "rendering available; enable AccessibilityService for input fallback"
        }
        return SupportInfo(true, "Trusted VirtualDisplay embedding available with $inputMode")
    }
}
