package com.carlauncher.car_launcher.embedding

import android.annotation.SuppressLint
import android.app.ActivityOptions
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PatternMatcher
import android.os.SystemClock
import android.os.UserManager
import android.util.Log
import android.view.InputEvent
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewTreeObserver
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

        // Backstop poll while waiting for the host to become ready. Focus
        // and unlock events normally wake us sooner.
        const val READINESS_POLL_MS = 500L

        // Backstop poll while the target package is missing/disabled (e.g.
        // mid-update at boot). Package broadcasts normally wake us sooner.
        const val PACKAGE_POLL_MS = 5_000L
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

    // "Not ready yet" (locked user, no window focus, unsized/invalid surface,
    // target package not launchable) is a normal transient state right after
    // boot, while a system dialog is up or while the target app updates.
    // It is waited out here without spending [MAX_CREATE_RETRIES],
    // which is reserved for real failures (ROM refuses the display, launch
    // throws). Otherwise an early launcher start burns the whole retry budget
    // and parks the pane on the permanent fallback.
    private var waitingForReadiness = false
    private val readinessRunnable = Runnable { attemptCreateVirtualDisplay() }
    private var unlockReceiver: BroadcastReceiver? = null
    private var packageReceiver: BroadcastReceiver? = null
    // Once the launcher window has had focus it is known to be in the
    // foreground. Focus then legitimately moves to the embedded apps' own
    // VirtualDisplays, so a pane created later (e.g. its package became
    // launchable) must not wait for focus to come back.
    private var hostWasFocused = false
    private val focusListener = ViewTreeObserver.OnWindowFocusChangeListener { hasFocus ->
        if (hasFocus) {
            hostWasFocused = true
            onReadinessSignal()
        }
    }
    private val attachListener = object : View.OnAttachStateChangeListener {
        override fun onViewAttachedToWindow(view: View) {
            view.viewTreeObserver.addOnWindowFocusChangeListener(focusListener)
            onReadinessSignal()
        }

        override fun onViewDetachedFromWindow(view: View) {
            view.viewTreeObserver.removeOnWindowFocusChangeListener(focusListener)
        }
    }
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
        root.addOnAttachStateChangeListener(attachListener)
        if (root.isAttachedToWindow) {
            root.viewTreeObserver.addOnWindowFocusChangeListener(focusListener)
        }
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
        // Focus/unlock signals can arrive after the display already exists.
        if (virtualDisplay != null) return
        if (!isReadyToCreate(holder)) {
            waitForReadiness()
            return
        }
        if (!isTargetLaunchable()) {
            waitForTargetPackage()
            return
        }
        stopWaitingForReadiness()
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
            releaseVirtualDisplay(hideSurface = false)
            scheduleCreateRetry("Cannot launch $targetPackage on display ${display.displayId}")
            return
        }
        createRetryCount = 0
    }

    private fun isReadyToCreate(holder: SurfaceHolder): Boolean {
        val userManager = root.context.getSystemService(UserManager::class.java)
        if (root.hasWindowFocus()) hostWasFocused = true
        return !disposed &&
            root.isAttachedToWindow &&
            hostWasFocused &&
            root.windowVisibility == View.VISIBLE &&
            surfaceView.width > 0 &&
            surfaceView.height > 0 &&
            holder.surface.isValid &&
            userManager.isUserUnlocked
    }

    private fun waitForReadiness() {
        if (disposed) return
        if (!waitingForReadiness) {
            waitingForReadiness = true
            registerUnlockReceiverIfLocked()
            Log.i(TAG, "Waiting for VirtualDisplay host readiness pane=$paneId package=$targetPackage")
        }
        mainHandler.removeCallbacks(readinessRunnable)
        mainHandler.postDelayed(readinessRunnable, READINESS_POLL_MS)
    }

    private fun isTargetLaunchable(): Boolean {
        val packageManager = root.context.packageManager
        return try {
            packageManager.getApplicationInfo(targetPackage, 0).enabled &&
                packageManager.getLaunchIntentForPackage(targetPackage) != null
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun waitForTargetPackage() {
        if (disposed) return
        if (packageReceiver == null) {
            registerPackageReceiver()
            Log.i(TAG, "Waiting for $targetPackage to become launchable pane=$paneId")
        }
        waitingForReadiness = true
        mainHandler.removeCallbacks(readinessRunnable)
        mainHandler.postDelayed(readinessRunnable, PACKAGE_POLL_MS)
    }

    private fun stopWaitingForReadiness() {
        waitingForReadiness = false
        mainHandler.removeCallbacks(readinessRunnable)
        unregisterUnlockReceiver()
        unregisterPackageReceiver()
    }

    private fun onReadinessSignal() {
        if (disposed || !waitingForReadiness) return
        mainHandler.removeCallbacks(readinessRunnable)
        mainHandler.post(readinessRunnable)
    }

    private fun registerUnlockReceiverIfLocked() {
        val userManager = root.context.getSystemService(UserManager::class.java)
        if (unlockReceiver != null || userManager?.isUserUnlocked != false) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                onReadinessSignal()
            }
        }
        val filter = IntentFilter(Intent.ACTION_USER_UNLOCKED)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                root.context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                root.context.registerReceiver(receiver, filter)
            }
            unlockReceiver = receiver
        } catch (error: Throwable) {
            // The readiness poll still covers unlock; the receiver only
            // shortens the wait.
            Log.w(TAG, "Unable to observe user unlock for pane=$paneId", error)
        }
    }

    private fun unregisterUnlockReceiver() {
        val receiver = unlockReceiver ?: return
        unlockReceiver = null
        try {
            root.context.unregisterReceiver(receiver)
        } catch (_: Throwable) {
        }
    }

    private fun registerPackageReceiver() {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                Log.i(TAG, "Package event ${intent?.action} for $targetPackage pane=$paneId")
                onReadinessSignal()
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_CHANGED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addDataScheme("package")
            addDataSchemeSpecificPart(targetPackage, PatternMatcher.PATTERN_LITERAL)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                root.context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                root.context.registerReceiver(receiver, filter)
            }
            packageReceiver = receiver
        } catch (error: Throwable) {
            // The package poll still covers this; the receiver only shortens
            // the wait.
            Log.w(TAG, "Unable to observe $targetPackage changes for pane=$paneId", error)
        }
    }

    private fun unregisterPackageReceiver() {
        val receiver = packageReceiver ?: return
        packageReceiver = null
        try {
            root.context.unregisterReceiver(receiver)
        } catch (_: Throwable) {
        }
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
        if (virtualDisplay == null) {
            // First real size is one of the readiness conditions.
            onReadinessSignal()
            return
        }
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
        stopWaitingForReadiness()
        virtualDisplay?.surface = null
    }

    // [hideSurface]=true (dispose/showFallback) intentionally hides the
    // SurfaceView, which triggers surfaceDestroyed() and nulls currentHolder.
    // The launch-failure retry path must pass false: hiding the surface
    // there destroys currentHolder before the scheduled retry runs, so
    // attemptCreateVirtualDisplay()'s `currentHolder ?: return` silently
    // no-ops forever — the retry never fires, createRetryCount never
    // reaches MAX_CREATE_RETRIES, and showFallback() never appears, leaving
    // a permanently blank pane with no explanation.
    private fun releaseVirtualDisplay(hideSurface: Boolean = true) {
        if (hideSurface) surfaceView.visibility = View.INVISIBLE
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
        // A direct startActivity() call lets the framework's permission check
        // (ActivityOptions.setLaunchDisplayId requires ADD_TRUSTED_DISPLAY on
        // most ROMs) throw synchronously back to us. Routing this through a
        // PendingIntent.send() instead — as this used to — hides that
        // SecurityException inside system_server: the send() call itself
        // never throws, so the failure was invisible here and the panes were
        // left blank forever instead of falling back to showFallback().
        return try {
            context.startActivity(intent, options.toBundle())
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

            stopWaitingForReadiness()
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
        stopWaitingForReadiness()
        root.removeOnAttachStateChangeListener(attachListener)
        root.viewTreeObserver.removeOnWindowFocusChangeListener(focusListener)
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
