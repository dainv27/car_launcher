package com.carlauncher.car_launcher.platform_view

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.GeolocationPermissions
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.TextView
import com.carlauncher.car_launcher.embedding.ActivityViewHelper
import io.flutter.plugin.platform.PlatformView

/**
 * PlatformView used by Flutter AndroidView(viewType = "google_maps_taskview").
 *
 * It tries to embed the real Google Maps app inside this view by using the
 * hidden android.app.ActivityView API through ActivityViewHelper.
 *
 * If the ROM does not support ActivityView, it keeps the launcher foregrounded
 * by rendering Google Maps Web in a WebView. That lets Flutter panels above
 * this PlatformView, such as YoutubeWidget, remain visible.
 */
class GoogleMapsPlatformView(
    private val context: Context,
    packageName: String? = null,
    private val autoLaunchFullscreenFallback: Boolean = false,
    private val fallbackMode: String = "web",
) : PlatformView {

    private companion object {
        const val GOOGLE_MAPS_PACKAGE = "com.google.android.apps.maps"
        val APPROVED_MAPS_ORIGINS = setOf(
            "https://www.google.com",
            "https://maps.google.com",
        )
    }

    private val rootView = FrameLayout(context)
    private var activityHost: ViewGroup? = null
    private var webView: WebView? = null
    private var fullscreenFallbackStarted = false
    private val targetPackage = packageName?.takeIf { it.isNotBlank() } ?: GOOGLE_MAPS_PACKAGE

    init {
        rootView.setBackgroundColor(Color.BLACK)
        rootView.isClickable = true
        rootView.isFocusable = true

        startEmbeddedGoogleMaps()
    }

    private fun startEmbeddedGoogleMaps() {
        if (!isPackageInstalled(targetPackage)) {
            showMessage(
                message = "Google Maps is not installed\nPackage: $targetPackage",
                color = Color.parseColor("#EF5350"),
                openOnTap = false,
            )
            return
        }

        val support = ActivityViewHelper.getSupportInfo()
        if (!support.supported) {
            if (fallbackMode == "overlay") {
                showFullscreenLaunchFallback(support.reason)
            } else {
                showWebMapsFallback(support.reason)
            }

            if (autoLaunchFullscreenFallback) {
                rootView.post { openGoogleMapsFullscreen() }
            }
            return
        }

        val host = ActivityViewHelper.createHost(context)
        activityHost = host

        if (!ActivityViewHelper.isActivityView(host)) {
            showMessage(
                message = "Failed to create ActivityView host\nTap to open Google Maps fullscreen",
                color = Color.parseColor("#EF5350"),
                openOnTap = true,
            )
            return
        }

        rootView.removeAllViews()
        rootView.addView(
            host,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )

        val launched = ActivityViewHelper.startApp(
            host = host,
            packageName = targetPackage,
            packageManager = context.packageManager,
        )

        if (!launched) {
            rootView.removeAllViews()
            if (fallbackMode == "overlay") {
                showFullscreenLaunchFallback("Cannot launch Google Maps inside ActivityView")
            } else {
                showWebMapsFallback("Cannot launch Google Maps inside ActivityView")
            }
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            context.packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun showFullscreenLaunchFallback(reason: String) {
        showMessage(
            message = "Opening Google Maps fullscreen\n$reason",
            color = Color.parseColor("#B3FFFFFF"),
            openOnTap = false,
        )

        if (!fullscreenFallbackStarted) {
            fullscreenFallbackStarted = true
            rootView.post { openGoogleMapsFullscreen() }
        }
    }

    private fun showWebMapsFallback(reason: String) {
        rootView.removeAllViews()
        rootView.setOnClickListener(null)

        val mapsWebView = WebView(context).apply {
            setBackgroundColor(Color.BLACK)
            isFocusable = true
            isFocusableInTouchMode = true

            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.cacheMode = WebSettings.LOAD_DEFAULT
            settings.loadsImagesAutomatically = true
            settings.mediaPlaybackRequiresUserGesture = false
            settings.setSupportZoom(true)
            settings.builtInZoomControls = true
            settings.displayZoomControls = false
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            settings.allowFileAccessFromFileURLs = false
            settings.allowUniversalAccessFromFileURLs = false
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW

            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(
                    view: WebView,
                    request: WebResourceRequest,
                ): Boolean {
                    return !isApprovedMapsOrigin(request.url)
                }
            }

            webChromeClient = object : WebChromeClient() {
                override fun onGeolocationPermissionsShowPrompt(
                    origin: String?,
                    callback: GeolocationPermissions.Callback?,
                ) {
                    val hasLocationPermission =
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                            context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
                            PackageManager.PERMISSION_GRANTED
                    val approved = hasLocationPermission &&
                        origin?.let { isApprovedMapsOrigin(Uri.parse(it)) } == true
                    callback?.invoke(origin, approved, false)
                }
            }
        }

        webView = mapsWebView
        rootView.addView(
            mapsWebView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )

        addFallbackBadge(reason)
        mapsWebView.loadUrl("https://www.google.com/maps")
    }

    private fun isApprovedMapsOrigin(uri: Uri?): Boolean {
        if (uri?.scheme?.lowercase() != "https") return false
        if (uri.port != -1 && uri.port != 443) return false
        val host = uri.host?.lowercase() ?: return false
        return "https://$host" in APPROVED_MAPS_ORIGINS
    }

    private fun addFallbackBadge(reason: String) {
        val label = TextView(context).apply {
            text = "Maps Web fallback\n$reason"
            textSize = 11f
            setTextColor(Color.parseColor("#B3FFFFFF"))
            setBackgroundColor(Color.parseColor("#99000000"))
            setPadding(16, 10, 16, 10)
        }

        val params = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
        ).apply {
            gravity = Gravity.START or Gravity.BOTTOM
            leftMargin = 16
            bottomMargin = 16
        }

        rootView.addView(label, params)
    }

    private fun showMessage(message: String, color: Int, openOnTap: Boolean) {
        rootView.removeAllViews()

        val label = TextView(context).apply {
            text = message
            textSize = 14f
            setTextColor(color)
            gravity = Gravity.CENTER
            setPadding(32, 32, 32, 32)
        }

        rootView.addView(
            label,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )

        if (openOnTap) {
            rootView.setOnClickListener { openGoogleMapsFullscreen() }
        } else {
            rootView.setOnClickListener(null)
        }
    }

    private fun openGoogleMapsFullscreen(): Boolean {
        return try {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(targetPackage)
                ?: Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_LAUNCHER)
                    setPackage(targetPackage)
                }

            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(launchIntent)
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun getView(): View = rootView

    override fun dispose() {
        activityHost?.let { ActivityViewHelper.release(it) }
        activityHost = null
        webView?.let { view ->
            rootView.removeView(view)
            view.stopLoading()
            view.webChromeClient = WebChromeClient()
            view.webViewClient = WebViewClient()
            view.destroy()
        }
        webView = null
        rootView.removeAllViews()
        rootView.setOnClickListener(null)
    }
}
