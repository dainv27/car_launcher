package com.carlauncher.car_launcher.embedding

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.widget.FrameLayout
import java.lang.reflect.Proxy
import java.util.concurrent.Executor

/**
 * Reflection wrapper around the hidden android.app.ActivityView API.
 * Works on Android 9+ system/privileged builds. Many aftermarket head units
 * need the launcher installed as a system app for embedding to render.
 */
object ActivityViewHelper {
    private const val TAG = "ActivityViewHelper"

    data class SupportInfo(
        val supported: Boolean,
        val reason: String,
    )

    fun getSupportInfo(): SupportInfo {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return SupportInfo(
                supported = false,
                reason = "Device is Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT}). Embedding needs Android 9+.",
            )
        }
        return try {
            Class.forName("android.app.ActivityView")
            SupportInfo(
                supported = true,
                reason = "ActivityView available on API ${Build.VERSION.SDK_INT}",
            )
        } catch (e: Exception) {
            SupportInfo(
                supported = false,
                reason = "ActivityView not available on this ROM: ${e.message}",
            )
        }
    }

    fun isSupported(): Boolean = getSupportInfo().supported

    fun findActivity(context: Context): Activity? {
        var current: Context? = context
        while (current is ContextWrapper) {
            if (current is Activity) return current
            current = current.baseContext
        }
        return null
    }

    fun createHost(context: Context): ViewGroup {
        val activity = findActivity(context) ?: context
        if (!isSupported()) {
            return FrameLayout(context)
        }
        return try {
            val clazz = Class.forName("android.app.ActivityView")
            createActivityView(clazz, activity)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to create ActivityView", e)
            FrameLayout(context)
        }
    }

    fun isActivityView(view: ViewGroup): Boolean {
        return view.javaClass.name == "android.app.ActivityView"
    }

    fun startApp(host: ViewGroup, packageName: String, packageManager: PackageManager): Boolean {
        if (!isActivityView(host)) return false

        val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
        intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_MULTIPLE_TASK or
                Intent.FLAG_ACTIVITY_NO_ANIMATION,
        )

        return try {
            val launch = Runnable {
                if (!invokeStartActivity(host, intent, packageName)) {
                    Log.e(TAG, "No supported ActivityView.startActivity signature worked for $packageName")
                }
            }

            registerReadyCallback(host) {
                if (host.isAttachedToWindow && host.width > 0 && host.height > 0) {
                    host.post(launch)
                } else {
                    host.viewTreeObserver.addOnGlobalLayoutListener(
                        object : ViewTreeObserver.OnGlobalLayoutListener {
                            override fun onGlobalLayout() {
                                if (host.width <= 0 || host.height <= 0) return
                                host.viewTreeObserver.removeOnGlobalLayoutListener(this)
                                host.post(launch)
                            }
                        },
                    )
                }
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to invoke ActivityView.startActivity", e)
            false
        }
    }

    private fun createActivityView(clazz: Class<*>, context: Context): ViewGroup {
        val constructorAttempts = listOf<Array<Class<*>>>(
            arrayOf(Context::class.java),
            arrayOf(Context::class.java, android.util.AttributeSet::class.java),
            arrayOf(Context::class.java, android.util.AttributeSet::class.java, Int::class.javaPrimitiveType!!),
            arrayOf(
                Context::class.java,
                android.util.AttributeSet::class.java,
                Int::class.javaPrimitiveType!!,
                Boolean::class.javaPrimitiveType!!,
            ),
        )

        var lastError: Exception? = null
        for (signature in constructorAttempts) {
            try {
                val ctor = clazz.getConstructor(*signature)
                val args = signature.map { type ->
                    when (type) {
                        Context::class.java -> context
                        android.util.AttributeSet::class.java -> null
                        Int::class.javaPrimitiveType -> 0
                        Boolean::class.javaPrimitiveType -> true
                        else -> null
                    }
                }.toTypedArray()
                return ctor.newInstance(*args) as ViewGroup
            } catch (e: Exception) {
                lastError = e
            }
        }

        throw lastError ?: NoSuchMethodException("No supported ActivityView constructor")
    }

    private fun invokeStartActivity(host: ViewGroup, intent: Intent, packageName: String): Boolean {
        try {
            val method = host.javaClass.getMethod("startActivity", Intent::class.java)
            method.invoke(host, intent)
            Log.i(TAG, "Embedded launch requested with Intent for $packageName")
            return true
        } catch (e: NoSuchMethodException) {
            Log.d(TAG, "ActivityView.startActivity(Intent) unavailable", e)
        } catch (e: Exception) {
            Log.w(TAG, "ActivityView.startActivity(Intent) failed", e)
        }

        return invokeStartActivityWithPendingIntent(host, intent, packageName)
    }

    private fun invokeStartActivityWithPendingIntent(
        host: ViewGroup,
        intent: Intent,
        packageName: String,
    ): Boolean {
        val requestCode = packageName.hashCode()
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val pendingIntent = PendingIntent.getActivity(host.context, requestCode, intent, flags)

        try {
            val method = host.javaClass.getMethod("startActivity", PendingIntent::class.java)
            method.invoke(host, pendingIntent)
            Log.i(TAG, "Embedded launch requested with PendingIntent for $packageName")
            return true
        } catch (e: NoSuchMethodException) {
            Log.d(TAG, "ActivityView.startActivity(PendingIntent) unavailable", e)
        } catch (e: Exception) {
            Log.w(TAG, "ActivityView.startActivity(PendingIntent) failed", e)
        }

        try {
            val method = host.javaClass.getMethod(
                "startActivity",
                PendingIntent::class.java,
                Intent::class.java,
                android.app.ActivityOptions::class.java,
            )
            val options = android.app.ActivityOptions.makeBasic()
            method.invoke(host, pendingIntent, null, options)
            Log.i(TAG, "Embedded launch requested with PendingIntent options for $packageName")
            return true
        } catch (e: NoSuchMethodException) {
            Log.d(TAG, "ActivityView.startActivity(PendingIntent, Intent, ActivityOptions) unavailable", e)
        } catch (e: Exception) {
            Log.w(TAG, "ActivityView.startActivity(PendingIntent, Intent, ActivityOptions) failed", e)
        }

        return false
    }

    private fun registerReadyCallback(host: ViewGroup, onReady: () -> Unit) {
        if (!isActivityView(host)) {
            onReady()
            return
        }
        try {
            val callbackClass = Class.forName("android.app.ActivityView\$StateCallback")
            val proxy = Proxy.newProxyInstance(
                callbackClass.classLoader,
                arrayOf(callbackClass),
            ) { _, method, _ ->
                if (method.name == "onActivityViewReady") {
                    host.post(onReady)
                }
                null
            }

            try {
                val method = host.javaClass.getMethod(
                    "setCallback",
                    Executor::class.java,
                    callbackClass,
                )
                method.invoke(host, Executor { command -> host.post(command) }, proxy)
                return
            } catch (_: NoSuchMethodException) {
                // Fall through to legacy callback signature.
            }

            val method = host.javaClass.getMethod("setCallback", callbackClass)
            method.invoke(host, proxy)
        } catch (e: Exception) {
            Log.w(TAG, "StateCallback unavailable, launching immediately", e)
            onReady()
        }
    }

    fun release(host: ViewGroup) {
        if (!isActivityView(host)) return
        try {
            val method = host.javaClass.getMethod("release")
            method.invoke(host)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to release ActivityView", e)
        }
    }
}
