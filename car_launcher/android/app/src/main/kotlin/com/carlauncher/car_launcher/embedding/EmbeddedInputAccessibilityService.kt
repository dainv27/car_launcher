package com.carlauncher.car_launcher.embedding

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.MotionEvent
import android.view.accessibility.AccessibilityEvent

/**
 * Opt-in fallback for ROMs that allow trusted VirtualDisplays but deny
 * INJECT_EVENTS. It never retrieves window content and only dispatches gestures
 * explicitly forwarded by an allow-listed embedded pane.
 */
class EmbeddedInputAccessibilityService : AccessibilityService() {
    companion object {
        private const val TAG = "EmbeddedInputA11y"
        private const val MAX_GESTURE_DURATION_MS = 59_000L

        @Volatile
        private var activeService: EmbeddedInputAccessibilityService? = null

        fun isReady(): Boolean = activeService != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R

        fun dispatchGesture(displayId: Int, gesture: RecordedGesture): Boolean {
            val service = activeService ?: return false
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
            return service.dispatchToDisplay(displayId, gesture)
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        activeService = this
        Log.i(TAG, "Virtual display input fallback connected")
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        if (activeService === this) activeService = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        if (activeService === this) activeService = null
        Log.i(TAG, "Virtual display input fallback disconnected")
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit

    override fun onInterrupt() = Unit

    private fun dispatchToDisplay(displayId: Int, recorded: RecordedGesture): Boolean {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            return mainHandler.post { dispatchToDisplay(displayId, recorded) }
        }
        val builder = GestureDescription.Builder().setDisplayId(displayId)
        recorded.strokes.forEach { stroke ->
            val startTimeMs = stroke.startTimeMs.coerceIn(0L, MAX_GESTURE_DURATION_MS - 1L)
            builder.addStroke(
                GestureDescription.StrokeDescription(
                    stroke.path,
                    startTimeMs,
                    stroke.durationMs.coerceIn(1L, MAX_GESTURE_DURATION_MS - startTimeMs),
                ),
            )
        }
        return dispatchGesture(builder.build(), null, null)
    }
}

data class RecordedGesture(
    val strokes: List<RecordedStroke>,
)

data class RecordedStroke(
    val path: Path,
    val startTimeMs: Long,
    val durationMs: Long,
)

class AccessibilityGestureRecorder {
    private data class ActiveStroke(
        val path: Path,
        val startTimeMs: Long,
        var endTimeMs: Long? = null,
    )

    private val strokes = linkedMapOf<Int, ActiveStroke>()
    private var startTimeMs = 0L

    fun record(event: MotionEvent): RecordedGesture? {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                reset()
                startTimeMs = event.eventTime
                addPointer(event, event.actionIndex)
            }
            MotionEvent.ACTION_POINTER_DOWN -> addPointer(event, event.actionIndex)
            MotionEvent.ACTION_MOVE -> addAllPointers(event)
            MotionEvent.ACTION_POINTER_UP -> appendPointer(event, event.actionIndex)
            MotionEvent.ACTION_UP -> {
                appendPointer(event, event.actionIndex)
                return finish(event.eventTime)
            }
            MotionEvent.ACTION_CANCEL -> reset()
        }
        return null
    }

    fun reset() {
        strokes.clear()
        startTimeMs = 0L
    }

    private fun addAllPointers(event: MotionEvent) {
        repeat(event.pointerCount) { index -> appendPointer(event, index) }
    }

    private fun addPointer(event: MotionEvent, index: Int) {
        strokes[event.getPointerId(index)] = ActiveStroke(
            path = Path().apply { moveTo(event.getX(index), event.getY(index)) },
            startTimeMs = offsetFor(event.eventTime),
        )
    }

    private fun appendPointer(event: MotionEvent, index: Int) {
        val stroke = strokes[event.getPointerId(index)] ?: return addPointer(event, index)
        stroke.path.lineTo(event.getX(index), event.getY(index))
        if (event.actionMasked == MotionEvent.ACTION_POINTER_UP ||
            event.actionMasked == MotionEvent.ACTION_UP
        ) {
            stroke.endTimeMs = offsetFor(event.eventTime)
        }
    }

    private fun finish(endTimeMs: Long): RecordedGesture? {
        if (strokes.isEmpty()) return null
        val endOffsetMs = offsetFor(endTimeMs)
        val gesture = RecordedGesture(
            strokes = strokes.values.map { stroke ->
                RecordedStroke(
                    path = Path(stroke.path),
                    startTimeMs = stroke.startTimeMs,
                    durationMs =
                        ((stroke.endTimeMs ?: endOffsetMs) - stroke.startTimeMs).coerceAtLeast(1L),
                )
            },
        )
        reset()
        return gesture
    }

    private fun offsetFor(eventTimeMs: Long): Long =
        (eventTimeMs - startTimeMs).coerceAtLeast(0L)
}
