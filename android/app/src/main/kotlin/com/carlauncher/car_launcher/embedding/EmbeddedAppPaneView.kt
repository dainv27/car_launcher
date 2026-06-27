package com.carlauncher.car_launcher.embedding

import android.content.Context
import android.graphics.Color
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import io.flutter.plugin.platform.PlatformView

class EmbeddedAppPaneView(
    context: Context,
    private val paneId: Int,
    packageName: String?,
) : PlatformView {
    private val root = FrameLayout(context)
    private var activityHost: ViewGroup? = null
    private val targetPackage = packageName?.trim().orEmpty()

    init {
        root.setBackgroundColor(Color.BLACK)

        if (targetPackage.isEmpty()) {
            showMessage("Tap to assign an app", Color.WHITE)
        } else {
            val support = ActivityViewHelper.getSupportInfo()
            if (!support.supported) {
                showMessage(
                    "Embedding unavailable on this device.\nOpen apps fullscreen instead.",
                    Color.parseColor("#FFB74D"),
                )
            } else {
                val host = ActivityViewHelper.createHost(context)
                activityHost = host
                if (!ActivityViewHelper.isActivityView(host)) {
                    showMessage(
                        "Could not create embed host for $targetPackage",
                        Color.parseColor("#EF5350"),
                    )
                } else {
                    root.addView(
                        host,
                        FrameLayout.LayoutParams(
                            FrameLayout.LayoutParams.MATCH_PARENT,
                            FrameLayout.LayoutParams.MATCH_PARENT,
                        ),
                    )

                    val launched = ActivityViewHelper.startApp(
                        host,
                        targetPackage,
                        context.packageManager,
                    )
                    if (!launched) {
                        showMessage(
                            "Cannot launch $targetPackage in pane",
                            Color.parseColor("#EF5350"),
                        )
                    }
                }
            }
        }
    }

    private fun showMessage(message: String, color: Int) {
        val label = TextView(root.context).apply {
            text = message
            setTextColor(color)
            gravity = Gravity.CENTER
            textSize = 12f
            setPadding(24, 24, 24, 24)
        }
        root.addView(
            label,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
    }

    override fun getView(): View = root

    override fun dispose() {
        activityHost?.let { ActivityViewHelper.release(it) }
        activityHost = null
        root.removeAllViews()
    }
}
