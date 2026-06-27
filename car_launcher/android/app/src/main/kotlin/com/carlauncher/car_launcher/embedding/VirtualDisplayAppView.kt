package com.carlauncher.car_launcher.embedding

import android.annotation.SuppressLint
import android.app.ActivityOptions
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.os.UserManager
import android.util.Log
import android.view.InputEvent
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.WindowInsets
import android.widget.FrameLayout
import android.widget.TextView
import android.widget.Toast
import io.flutter.plugin.platform.PlatformView
import java.lang.reflect.Field
import java.lang.reflect.Method

/**
 * CarCar-style embedded app host.
 *
 * The target activity runs fullscreen on a dedicated VirtualDisplay whose
 * surface is rendered inside this PlatformView. Launching and input injection
 * require the launcher to be platform-signed and installed as a privileged
 * system app on most Android 13 ROMs.
 */
class VirtualDisplayAppView(
    context: Context,
    private val paneId: Int,
    packageName: String?,
    zOrderOnTop: Boolean,
) : PlatformView, SurfaceHolder.Callback {
    private companion object {
        const val TAG = "VirtualDisplayAppView"

        // CarCar Android 13 uses trusted flags 3337. Its compatibility path uses
        // public/own-content/destroy-on-removal flags 265.
        const val TRUSTED_VIRTUAL_DISPLAY_FLAGS = 3337
        const val COMPAT_VIRTUAL_DISPLAY_FLAGS = 265
        const val INJECT_INPUT_EVENT_MODE_ASYNC = 0
        const val MAX_CREATE_RETRIES = 5
        const val BASE_RETRY_DELAY_MS = 250L
        const val MAX_RETRY_DELAY_MS = 4_000L
        val ALLOWED_PACKAGES = setOf(
            "com.google.android.apps.maps",
            "com.google.android.youtube",
        )
    }

    private val root = FrameLayout(context)
    private val surfaceView = SurfaceView(context)
    private val targetPackage = packageName?.trim().orEmpty()
    private var virtualDisplay: VirtualDisplay? = null
    private var fallbackHost: android.view.ViewGroup? = null
    private var disposed = false
    private var lastDisplayWidth = 0
    private var lastDisplayHeight = 0
    private var currentHolder: SurfaceHolder? = null
    private var createRetryCount = 0
    private val mainHandler = Handler(Looper.getMainLooper())
    private val createRetryRunnable = Runnable { attemptCreateVirtualDisplay() }
    private val accessibilityGestureRecorder = AccessibilityGestureRecorder()
    private val inputManager by lazy { root.context.getSystemService(Context.INPUT_SERVICE) }
    private val injectInputEventMethod: Method? by lazy {
        inputManager.javaClass.declaredMethods.firstOrNull {
            it.name == "injectInputEvent" && it.parameterTypes.size == 2
        }?.apply { isAccessible = true }
    }
    private val setDisplayIdMethod: Method? by lazy { resolveSetDisplayIdMethod() }
    private val displayIdField: Field? by lazy {
        runCatching {
            InputEvent::class.java.getDeclaredField("mDisplayId").apply {
                isAccessible = true
            }
        }.getOrNull()
    }
    private var directInputAvailable = true
    private var lastAccessibilityHintMs = 0L

    init {
        root.setBackgroundColor(Color.BLACK)
        if (targetPackage !in ALLOWED_PACKAGES) {
            showFallback("Package is not allowed for privileged embedding: $targetPackage")
        } else {
            setupVirtualDisplaySurface(zOrderOnTop)
        }
    }

    private fun setupVirtualDisplaySurface(zOrderOnTop: Boolean) {
        surfaceView.setZOrderMediaOverlay(zOrderOnTop)
        surfaceView.isClickable = true
        surfaceView.isFocusable = true
        surfaceView.isFocusableInTouchMode = true
        surfaceView.holder.addCallback(this)
        surfaceView.setOnTouchListener { _, event ->
            forwardMotionEvent(event)
            true
        }
        surfaceView.setOnGenericMotionListener { _, event ->
            forwardMotionEvent(event)
            true
        }
        surfaceView.setOnKeyListener { _, _, event ->
            injectInputEvent(KeyEvent(event))
            true
        }
        root.addView(
            surfaceView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        if (disposed || targetPackage.isEmpty()) return
        currentHolder = holder
        surfaceView.visibility = View.VISIBLE
        virtualDisplay?.let { display ->
            display.surface = holder.surface
            return
        }
        attemptCreateVirtualDisplay()
    }

    private fun attemptCreateVirtualDisplay() {
        val holder = currentHolder ?: return
        if (!isReadyToCreate(holder)) {
            scheduleCreateRetry("VirtualDisplay host is not ready")
            return
        }
        val width = surfaceView.width.coerceAtLeast(1)
        val height = surfaceView.height.coerceAtLeast(1)
        lastDisplayWidth = width
        lastDisplayHeight = height
        val density = root.resources.displayMetrics.densityDpi
        val displayManager = root.context.getSystemService(DisplayManager::class.java)

        virtualDisplay = createTrustedVirtualDisplayIfAllowed(
            displayManager,
            width,
            height,
            density,
            holder,
        ) ?: createVirtualDisplay(
            displayManager = displayManager,
            width = width,
            height = height,
            density = density,
            holder = holder,
            flags = COMPAT_VIRTUAL_DISPLAY_FLAGS,
        )

        val display = virtualDisplay?.display
        if (display == null) {
            scheduleCreateRetry("Cannot create VirtualDisplay on this ROM")
            return
        }

        Log.i(TAG, "Created pane=$paneId display=${display.displayId} package=$targetPackage")
        logInputCapability(display.displayId)
        if (!launchOnDisplay(display.displayId)) {
            releaseVirtualDisplay()
            scheduleCreateRetry("Cannot launch $targetPackage on display ${display.displayId}")
            return
        }
        createRetryCount = 0
    }

    private fun isReadyToCreate(holder: SurfaceHolder): Boolean {
        val userManager = root.context.getSystemService(UserManager::class.java)
        return !disposed &&
            root.isAttachedToWindow &&
            root.hasWindowFocus() &&
            surfaceView.width > 0 &&
            surfaceView.height > 0 &&
            holder.surface.isValid &&
            userManager.isUserUnlocked
    }

    private fun scheduleCreateRetry(reason: String) {
        if (disposed) return
        if (createRetryCount >= MAX_CREATE_RETRIES) {
            showFallback(reason)
            return
        }
        createRetryCount += 1
        val delay = (BASE_RETRY_DELAY_MS * (1L shl (createRetryCount - 1)))
            .coerceAtMost(MAX_RETRY_DELAY_MS)
        mainHandler.removeCallbacks(createRetryRunnable)
        mainHandler.postDelayed(createRetryRunnable, delay)
    }

    private fun createTrustedVirtualDisplayIfAllowed(
        displayManager: DisplayManager,
        width: Int,
        height: Int,
        density: Int,
        holder: SurfaceHolder,
    ): VirtualDisplay? {
        if (!hasPermission("android.permission.ADD_TRUSTED_DISPLAY")) return null
        return createVirtualDisplay(
            displayManager = displayManager,
            width = width,
            height = height,
            density = density,
            holder = holder,
            flags = TRUSTED_VIRTUAL_DISPLAY_FLAGS,
        )
    }

    private fun createVirtualDisplay(
        displayManager: DisplayManager,
        width: Int,
        height: Int,
        density: Int,
        holder: SurfaceHolder,
        flags: Int,
    ): VirtualDisplay? {
        return try {
            displayManager.createVirtualDisplay(
                "CarLauncherAppView@$paneId",
                width,
                height,
                density,
                holder.surface,
                flags,
            ).also {
                Log.i(TAG, "Created VirtualDisplay with flags=$flags for $targetPackage")
            }
        } catch (error: Throwable) {
            Log.w(TAG, "Cannot create VirtualDisplay flags=$flags for $targetPackage", error)
            null
        }
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        if (width <= 0 || height <= 0) return
        if (isImeVisible() && width <= lastDisplayWidth && height < lastDisplayHeight) {
            Log.i(
                TAG,
                "Ignoring IME-driven VirtualDisplay resize pane=$paneId " +
                    "${lastDisplayWidth}x$lastDisplayHeight -> ${width}x$height",
            )
            return
        }
        lastDisplayWidth = width
        lastDisplayHeight = height
        virtualDisplay?.resize(width, height, root.resources.displayMetrics.densityDpi)
    }

    private fun isImeVisible(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        return root.rootWindowInsets?.isVisible(WindowInsets.Type.ime()) == true
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        currentHolder = null
        mainHandler.removeCallbacks(createRetryRunnable)
        virtualDisplay?.surface = null
    }

    private fun releaseVirtualDisplay() {
        surfaceView.visibility = View.INVISIBLE
        val display = virtualDisplay
        virtualDisplay = null
        try {
            display?.surface = null
        } catch (error: Throwable) {
            Log.d(TAG, "Unable to detach VirtualDisplay surface for pane=$paneId", error)
        }
        display?.release()
    }

    private fun launchOnDisplay(displayId: Int): Boolean {
        val context = root.context
        val intent = context.packageManager.getLaunchIntentForPackage(targetPackage) ?: return false
        intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_MULTIPLE_TASK or
                Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED or
                Intent.FLAG_ACTIVITY_NO_ANIMATION,
        )

        val options = ActivityOptions.makeBasic().apply {
            launchDisplayId = displayId
        }
        return try {
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            PendingIntent.getActivity(context, targetPackage.hashCode(), intent, flags)
                .send(context, 0, null, null, null, null, options.toBundle())
            true
        } catch (error: Throwable) {
            Log.w(TAG, "Cannot launch $targetPackage on display $displayId", error)
            false
        }
    }

    private fun forwardMotionEvent(source: MotionEvent) {
        when (source.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                surfaceView.requestFocus()
                surfaceView.parent?.requestDisallowInterceptTouchEvent(true)
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                surfaceView.parent?.requestDisallowInterceptTouchEvent(false)
            }
        }
        val displayId = virtualDisplay?.display?.displayId ?: return
        val recordedGesture = accessibilityGestureRecorder.record(source)
        if (directInputAvailable) {
            directInputAvailable = injectInputEvent(MotionEvent.obtain(source))
        }
        if (!directInputAvailable && recordedGesture != null) {
            val dispatched =
                EmbeddedInputAccessibilityService.dispatchGesture(displayId, recordedGesture)
            Log.i(
                TAG,
                "Accessibility input fallback pane=$paneId display=$displayId " +
                    "dispatched=$dispatched",
            )
            if (!dispatched) showAccessibilityFallbackHint()
        }
    }

    private fun showAccessibilityFallbackHint() {
        val now = SystemClock.elapsedRealtime()
        if (now - lastAccessibilityHintMs < 10_000L) return
        lastAccessibilityHintMs = now
        Toast.makeText(
            root.context,
            "Enable Virtual display input fallback in Android Accessibility settings",
            Toast.LENGTH_LONG,
        ).show()
    }

    private fun injectInputEvent(event: InputEvent): Boolean {
        val displayId = virtualDisplay?.display?.displayId ?: return false
        return try {
            assignDisplayId(event, displayId)
            val injectMethod = injectInputEventMethod
                ?: throw NoSuchMethodException("InputManager.injectInputEvent")
            val injected = injectMethod.invoke(
                inputManager,
                event,
                INJECT_INPUT_EVENT_MODE_ASYNC,
            ) as? Boolean
            injected == true
        } catch (error: Throwable) {
            Log.w(TAG, "Input injection failed for display $displayId", error)
            false
        } finally {
            if (event is MotionEvent) {
                event.recycle()
            }
        }
    }

    private fun logInputCapability(displayId: Int) {
        val hasInjectEvents = hasInjectEventsPermission()
        Log.i(
            TAG,
            "Input capability pane=$paneId display=$displayId package=$targetPackage " +
                "injectEvents=$hasInjectEvents",
        )
        directInputAvailable = true
    }

    private fun hasInjectEventsPermission(): Boolean {
        return hasPermission("android.permission.INJECT_EVENTS")
    }

    private fun hasPermission(permission: String): Boolean {
        return root.context.packageManager.checkPermission(permission, root.context.packageName) ==
            PackageManager.PERMISSION_GRANTED
    }

    @SuppressLint("PrivateApi", "BlockedPrivateApi")
    private fun resolveSetDisplayIdMethod(): Method? {
        return runCatching {
            InputEvent::class.java.getDeclaredMethod(
                "setDisplayId",
                Int::class.javaPrimitiveType,
            ).apply { isAccessible = true }
        }.getOrNull()
    }

    @SuppressLint("PrivateApi", "BlockedPrivateApi")
    private fun assignDisplayId(event: InputEvent, displayId: Int) {
        setDisplayIdMethod?.let { method ->
            method.invoke(event, displayId)
            return
        }
        displayIdField?.setInt(event, displayId)
            ?: throw NoSuchFieldException("InputEvent display ID setter")
    }

    private fun showFallback(reason: String) {
        root.post {
            if (disposed) return@post

            releaseVirtualDisplay()
            surfaceView.holder.removeCallback(this)
            root.removeAllViews()

            root.addView(
                TextView(root.context).apply {
                    text = "$reason\nPrivileged/platform-signed installation required"
                    setTextColor(Color.WHITE)
                    gravity = android.view.Gravity.CENTER
                    setPadding(24, 24, 24, 24)
                },
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ),
            )
        }
    }

    override fun getView(): View = root

    override fun dispose() {
        disposed = true
        mainHandler.removeCallbacks(createRetryRunnable)
        currentHolder = null
        surfaceView.holder.removeCallback(this)
        surfaceView.setOnTouchListener(null)
        surfaceView.setOnGenericMotionListener(null)
        surfaceView.setOnKeyListener(null)
        fallbackHost?.let(ActivityViewHelper::release)
        fallbackHost = null
        releaseVirtualDisplay()
        root.removeAllViews()
    }
}
