package com.carlauncher.car_launcher.embedding

import android.os.SystemClock
import android.util.Log

/**
 * Structured logger for the VirtualDisplay subsystem.
 *
 * Every log line is tagged with a phase prefix so you can filter Logcat by
 * lifecycle phase:
 *
 *   adb logcat -s VDReadinessGate:* VDAppView:* VDLauncher:*
 *
 * Phase tags (appear as the first token in the message):
 *   [BOOT]       — boot / user-unlock / boot-fallback events
 *   [LIFECYCLE]  — activity resume/pause, window focus, view attach/detach
 *   [SURFACE]    — SurfaceHolder callbacks, layout, IME visibility
 *   [DISPLAY]    — DisplayManager display added/removed/changed
 *   [VD]         — VirtualDisplay create / resize / release / surface assign
 *   [LAUNCH]     — app launch via PendingIntent, retry scheduling
 *   [INPUT]      — input injection, accessibility bridge
 *   [STATE]      — readiness-gate state machine transitions
 *   [FALLBACK]   — fallback UI shown, permission prompts
 *
 * Each line includes:
 *   pane=<paneId> pkg=<packageName>  (when a pane context exists)
 *   ts=<uptimeMs>                   (milliseconds since boot — lets you see
 *                                    how long after boot each event fires)
 *   step=<n>                        (monotonic counter within a pane instance)
 */
object VDLogger {

    private const val TAG_GATE = "VDReadinessGate"
    private const val TAG_VIEW = "VDAppView"
    private const val TAG_LAUNCHER = "VDLauncher"

    @Volatile private var bannerEmitted = false

    private fun ts(): Long = SystemClock.elapsedRealtime()

    private fun build(
        phase: String,
        paneId: Int = -1,
        pkg: String = "",
        step: Int = 0,
        msg: String,
        extra: Map<String, Any?> = emptyMap(),
    ): String {
        val sb = StringBuilder()
        sb.append("[$phase]")
        if (paneId >= 0) sb.append(" pane=$paneId")
        if (pkg.isNotEmpty()) sb.append(" pkg=$pkg")
        sb.append(" ts=${ts()}")
        if (step > 0) sb.append(" step=$step")
        sb.append(" | $msg")
        if (extra.isNotEmpty()) {
            sb.append(" | ")
            extra.entries.joinTo(sb, " ") { "${it.key}=${it.value}" }
        }
        return sb.toString()
    }

    // ── gate lifecycle ───────────────────────────────────────────────────

    fun logGateRegister(apiLevel: Int, hasDisplayManager: Boolean) {
        i(TAG_GATE, build("BOOT", msg = "Gate registered", extra = mapOf(
            "api" to apiLevel,
            "displayManager" to hasDisplayManager,
        )))
    }

    fun logGateUnregister() {
        i(TAG_GATE, build("BOOT", msg = "Gate unregistered"))
    }

    fun logBootFallback(elapsedRealtimeMs: Long) {
        i(TAG_GATE, build("BOOT", msg = "Boot fallback triggered", extra = mapOf(
            "elapsedRealtimeMs" to elapsedRealtimeMs,
            "thresholdMs" to 30_000L,
        )))
    }

    fun logBroadcast(action: String, hasUserUnlocked: Boolean? = null) {
        val extra = if (hasUserUnlocked != null) mapOf("userUnlocked" to hasUserUnlocked) else emptyMap()
        d(TAG_GATE, build("BOOT", msg = "Broadcast $action", extra = extra))
    }

    fun logUserUnlockedState(unlocked: Boolean, source: String) {
        i(TAG_GATE, build("BOOT", msg = "User unlocked=$unlocked (source=$source)"))
    }

    fun logDisplayEvent(event: String, displayId: Int, isDefault: Boolean) {
        d(TAG_GATE, build("DISPLAY", msg = "$event displayId=$displayId", extra = mapOf(
            "isDefault" to isDefault,
        )))
    }

    fun logDisplayAvailable(available: Boolean) {
        i(TAG_GATE, build("DISPLAY", msg = "Display available=$available"))
    }

    fun logLifecycle(flag: String, value: Boolean) {
        d(TAG_GATE, build("LIFECYCLE", msg = "$flag=$value"))
    }

    fun logSurface(flag: Boolean) {
        d(TAG_GATE, build("SURFACE", msg = "surfaceValid=$flag"))
    }

    fun logLayoutDone(width: Int, height: Int) {
        d(TAG_GATE, build("SURFACE", msg = "layoutDone ${width}x${height}"))
    }

    fun logViewAttached(attached: Boolean) {
        d(TAG_GATE, build("LIFECYCLE", msg = "viewAttached=$attached"))
    }

    fun logViewAttached(paneId: Int, pkg: String, attached: Boolean) {
        d(TAG_GATE, build("LIFECYCLE", paneId, pkg, 0, "viewAttached=$attached"))
    }

    fun logStateTransition(from: String, to: String, checks: Map<String, Boolean>) {
        i(TAG_GATE, build("STATE", msg = "$from -> $to", extra = checks))
    }

    fun logReadyToCreate() {
        i(TAG_GATE, build("STATE", msg = "READY — all checks passed, notifying listeners"))
    }

    fun logAttemptCreate(ready: Boolean, creating: Boolean) {
        d(TAG_GATE, build("VD", msg = "attemptCreate ready=$ready creating=$creating"))
    }

    fun logBeginCreating() {
        d(TAG_GATE, build("VD", msg = "beginCreating"))
    }

    fun logEndCreating(success: Boolean, retryCount: Int) {
        if (success) {
            i(TAG_GATE, build("VD", msg = "endCreating SUCCESS (retries=$retryCount)"))
        } else {
            w(TAG_GATE, build("VD", msg = "endCreating FAILED (retries=$retryCount)"))
        }
    }

    fun logRetryScheduled(retry: Int, maxRetries: Int, delayMs: Long) {
        i(TAG_GATE, build("VD", msg = "Retry #$retry/$maxRetries scheduled in ${delayMs}ms (exponential backoff)"))
    }

    fun logRetryGaveUp(maxRetries: Int) {
        w(TAG_GATE, build("VD", msg = "GAVE UP after $maxRetries retries"))
    }

    fun logCurrentState(state: String, checks: Map<String, Any?>) {
        d(TAG_GATE, build("STATE", msg = "currentState=$state", extra = checks))
    }

    // ── view lifecycle ───────────────────────────────────────────────────

    fun logViewInit(paneId: Int, pkg: String, zOrderOnTop: Boolean, allowed: Boolean) {
        i(TAG_VIEW, build("LIFECYCLE", paneId, pkg, 0, "init zOrderOnTop=$zOrderOnTop allowed=$allowed"))
    }

    fun logViewSetupSurface(paneId: Int, pkg: String, zOrderOnTop: Boolean) {
        d(TAG_VIEW, build("SURFACE", paneId, pkg, 0, "setupVirtualDisplaySurface zOrderMediaOverlay=$zOrderOnTop"))
    }

    fun logViewSurfaceCreated(paneId: Int, pkg: String, surfaceValid: Boolean) {
        i(TAG_VIEW, build("SURFACE", paneId, pkg, 0, "surfaceCreated surfaceValid=$surfaceValid"))
    }

    fun logViewSurfaceChanged(paneId: Int, pkg: String, width: Int, height: Int, format: Int) {
        d(TAG_VIEW, build("SURFACE", paneId, pkg, 0, "surfaceChanged ${width}x${height} format=$format"))
    }

    fun logViewSurfaceDestroyed(paneId: Int, pkg: String, displayId: Int?) {
        d(TAG_VIEW, build("SURFACE", paneId, pkg, 0, "surfaceDestroyed displayId=$displayId"))
    }

    fun logViewLayoutDone(paneId: Int, pkg: String, width: Int, height: Int) {
        i(TAG_VIEW, build("SURFACE", paneId, pkg, 0, "layout done ${width}x${height}"))
    }

    fun logViewVdCreateStart(paneId: Int, pkg: String, width: Int, height: Int, density: Int) {
        i(TAG_VIEW, build("VD", paneId, pkg, 0, "createVirtualDisplay START ${width}x${height} density=$density"))
    }

    fun logVdCreateAttempt(paneId: Int, pkg: String, flags: Int) {
        d(TAG_VIEW, build("VD", paneId, pkg, 0, "createVirtualDisplay flags=$flags"))
    }

    fun logVdCreateSuccess(paneId: Int, pkg: String, flags: Int, displayId: Int) {
        i(TAG_VIEW, build("VD", paneId, pkg, 0, "createVirtualDisplay SUCCESS flags=$flags displayId=$displayId"))
    }

    fun logVdCreateFailed(paneId: Int, pkg: String, flags: Int, error: Throwable) {
        w(TAG_VIEW, build("VD", paneId, pkg, 0, "createVirtualDisplay FAILED flags=$flags ${error.javaClass.simpleName}: ${error.message}"))
    }

    fun logVdCreateFallback(paneId: Int, pkg: String, fromFlags: Int, toFlags: Int) {
        w(TAG_VIEW, build("VD", paneId, pkg, 0, "createVirtualDisplay fallback flags $fromFlags -> $toFlags"))
    }

    fun logVdCreateNull(paneId: Int, pkg: String) {
        w(TAG_VIEW, build("VD", paneId, pkg, 0, "createVirtualDisplay FAILED — null after both flag attempts"))
    }

    fun logVdResize(paneId: Int, pkg: String, fromW: Int, fromH: Int, toW: Int, toH: Int) {
        d(TAG_VIEW, build("VD", paneId, pkg, 0, "resize ${fromW}x${fromH} -> ${toW}x${toH}"))
    }

    fun logVdRelease(paneId: Int, pkg: String, displayId: Int?) {
        i(TAG_VIEW, build("VD", paneId, pkg, 0, "releaseVirtualDisplay displayId=$displayId"))
    }

    fun logVdSurfaceDetach(paneId: Int, pkg: String) {
        d(TAG_VIEW, build("VD", paneId, pkg, 0, "surface detached"))
    }

    fun logVdSurfaceReattach(paneId: Int, pkg: String, displayId: Int) {
        i(TAG_VIEW, build("VD", paneId, pkg, 0, "reattaching surface to existing VD displayId=$displayId"))
    }

    fun logAppLaunchStart(paneId: Int, pkg: String, displayId: Int, retry: Int, maxRetries: Int) {
        i(TAG_VIEW, build("LAUNCH", paneId, pkg, 0, "launchOnDisplay START displayId=$displayId retry=$retry/$maxRetries"))
    }

    fun logAppLaunchIntent(paneId: Int, pkg: String, intent: String) {
        d(TAG_VIEW, build("LAUNCH", paneId, pkg, 0, "launchIntent=$intent"))
    }

    fun logAppLaunchPendingIntent(paneId: Int, pkg: String, requestCode: Int) {
        d(TAG_VIEW, build("LAUNCH", paneId, pkg, 0, "PendingIntent requestCode=$requestCode"))
    }

    fun logAppLaunchResult(paneId: Int, pkg: String, displayId: Int) {
        i(TAG_VIEW, build("LAUNCH", paneId, pkg, 0, "launchOnDisplay SUCCESS displayId=$displayId"))
    }

    fun logAppLaunchFailed(paneId: Int, pkg: String, error: Throwable) {
        w(TAG_VIEW, build("LAUNCH", paneId, pkg, 0, "launchOnDisplay FAILED ${error.javaClass.simpleName}: ${error.message}"))
    }

    fun logAppLaunchNullIntent(paneId: Int, pkg: String) {
        w(TAG_VIEW, build("LAUNCH", paneId, pkg, 0, "getLaunchIntentForPackage returned null"))
    }

    fun logAppLaunchRetry(paneId: Int, pkg: String, retry: Int, maxRetries: Int, delayMs: Long) {
        i(TAG_VIEW, build("LAUNCH", paneId, pkg, 0, "retry #$retry/$maxRetries in ${delayMs}ms (exponential backoff)"))
    }

    fun logAppLaunchGaveUp(paneId: Int, pkg: String, maxRetries: Int, displayId: Int) {
        w(TAG_VIEW, build("LAUNCH", paneId, pkg, 0, "GAVE UP after $maxRetries retries on displayId=$displayId"))
    }

    fun logRelaunch(paneId: Int, pkg: String, displayId: Int?) {
        i(TAG_VIEW, build("LAUNCH", paneId, pkg, 0, "relaunchOnDisplay displayId=$displayId"))
    }

    fun logReadyToCreateReceived(paneId: Int, pkg: String) {
        i(TAG_VIEW, build("STATE", paneId, pkg, 0, "onReadyToCreate — gate reports READY"))
    }

    fun logStateChanged(paneId: Int, pkg: String, state: String, checks: Map<String, Any?>) {
        d(TAG_VIEW, build("STATE", paneId, pkg, 0, "onStateChanged state=$state", checks))
    }

    fun logGateNotReady(paneId: Int, pkg: String) {
        d(TAG_VIEW, build("STATE", paneId, pkg, 0, "gate not ready, deferring"))
    }

    fun logInputCapability(paneId: Int, pkg: String, displayId: Int, hasInjectEvents: Boolean) {
        i(TAG_VIEW, build("INPUT", paneId, pkg, 0, "Input capability: display=$displayId injectEvents=$hasInjectEvents"))
    }

    fun logInputInjectionFailed(paneId: Int, displayId: Int, error: Throwable) {
        w(TAG_VIEW, build("INPUT", paneId, msg = "Input injection failed for display $displayId: ${error.javaClass.simpleName}: ${error.message}"))
    }

    fun logFallback(paneId: Int, pkg: String, reason: String) {
        w(TAG_VIEW, build("FALLBACK", paneId, pkg, 0, reason))
    }

    fun logDispose(paneId: Int, pkg: String, displayId: Int?) {
        i(TAG_VIEW, build("LIFECYCLE", paneId, pkg, 0, "dispose displayId=$displayId"))
    }

    // ── MainActivity ─────────────────────────────────────────────────────

    fun logMainActivityRegisterGate() {
        i(TAG_LAUNCHER, build("BOOT", msg = "MainActivity registered VirtualDisplayReadinessGate"))
    }

    fun logMainActivityLifecycle(event: String) {
        d(TAG_LAUNCHER, build("LIFECYCLE", msg = "MainActivity.$event"))
    }

    fun logMainActivityFocus(hasFocus: Boolean) {
        d(TAG_LAUNCHER, build("LIFECYCLE", msg = "MainActivity.onWindowFocusChanged hasFocus=$hasFocus"))
    }

    // ── banner ───────────────────────────────────────────────────────────

    fun emitBanner() {
        if (bannerEmitted) return
        bannerEmitted = true
        i(TAG_GATE, build("BOOT", msg = "=== VirtualDisplay ReadinessGate active ==="))
        i(TAG_GATE, build("BOOT", msg = "Filter Logcat with: adb logcat -s VDReadinessGate:* VDAppView:* VDLauncher:*"))
    }

    // ── level wrappers ───────────────────────────────────────────────────

    private fun d(tag: String, msg: String) = Log.d(tag, msg)
    private fun i(tag: String, msg: String) = Log.i(tag, msg)
    private fun w(tag: String, msg: String) = Log.w(tag, msg)
}
