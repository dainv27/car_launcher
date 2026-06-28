package com.carlauncher.car_launcher

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Base64
import android.util.Log
import java.io.ByteArrayOutputStream
import android.os.Handler
import android.os.Looper
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import com.carlauncher.car_launcher.embedding.EmbeddedAppPaneFactory
import com.carlauncher.car_launcher.embedding.EmbeddedInputAccessibilityService
import com.carlauncher.car_launcher.embedding.VirtualDisplayAppViewFactory
import com.carlauncher.car_launcher.embedding.VirtualDisplayEmbeddingCapability
import com.carlauncher.car_launcher.embedding.VDLogger
import com.carlauncher.car_launcher.platform_view.GoogleMapsPlatformViewFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.dart.DartExecutor
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.carlauncher/native"
    private val EVENT_CHANNEL = "com.carlauncher/events"
    private val NAV_METHOD_CHANNEL = "com.carlauncher/navigation"
    private val NAV_EVENT_CHANNEL = "com.carlauncher/nav_events"
    private val MEDIA_EVENT_CHANNEL = "com.carlauncher/media_events"

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var oauthChannel: MethodChannel? = null
    private var navMethodChannel: MethodChannel? = null
    private var navEventChannel: EventChannel? = null
    private var mediaEventChannel: EventChannel? = null
    private var pendingOAuthCallback: String? = null
    private var oauthDeliveryInFlight = false
    private val oauthDeliveryHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    private var navEventSink: EventChannel.EventSink? = null
    private var mediaEventSink: EventChannel.EventSink? = null
    private var appPackageChangedReceiver: BroadcastReceiver? = null

    private var mediaSessionManager: MediaSessionManager? = null
    private var mediaControllerCallback: MediaController.Callback? = null
    private var activeSessionsChangedListener: MediaSessionManager.OnActiveSessionsChangedListener? = null
    private var activeMediaController: MediaController? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyImmersiveFullscreen()
        processOAuthCallback(intent)
    }

    override fun onResume() {
        super.onResume()
        applyImmersiveFullscreen()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        processOAuthCallback(intent)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == STARTUP_PERMISSION_REQUEST) {
            openNextStartupPermissionSettings()
        }
    }

    private fun processOAuthCallback(callbackIntent: Intent?) {
        try {
            val data = callbackIntent?.data
            if (!isOAuthCallback(data)) {
                return
            }
            pendingOAuthCallback = data.toString()
            flushPendingOAuthCallback()
        } catch (e: Exception) {
            Log.w("MainActivity", "Unable to process OAuth callback", e)
        }
    }

    private fun flushPendingOAuthCallback() {
        val callback = pendingOAuthCallback ?: return
        val channel = oauthChannel ?: return
        if (oauthDeliveryInFlight) return
        oauthDeliveryInFlight = true
        channel.invokeMethod("onOAuthRedirect", callback, object : MethodChannel.Result {
            override fun success(result: Any?) {
                if (pendingOAuthCallback == callback) pendingOAuthCallback = null
                oauthDeliveryInFlight = false
                flushPendingOAuthCallback()
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                retryPendingOAuthCallback()
            }

            override fun notImplemented() {
                retryPendingOAuthCallback()
            }
        })
    }

    private fun retryPendingOAuthCallback() {
        oauthDeliveryInFlight = false
        oauthDeliveryHandler.postDelayed(::flushPendingOAuthCallback, 250L)
    }

    private fun isOAuthCallback(data: Uri?): Boolean {
        return data?.scheme == "carlauncher" &&
            data.host == "oauth" &&
            data.path == "/callback"
    }

    override fun onPause() {
        super.onPause()
        VDLogger.logMainActivityLifecycle("onPause")
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            applyImmersiveFullscreen()
        }
    }

    @Suppress("DEPRECATION")
    private fun applyImmersiveFullscreen() {
        window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.apply {
                hide(WindowInsets.Type.systemBars())
                systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
            return
        }

        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory("embedded_app_pane", EmbeddedAppPaneFactory())

        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory("virtual_display_app", VirtualDisplayAppViewFactory())

        flutterEngine.platformViewsController
            .registry
            .registerViewFactory("google_maps_taskview", GoogleMapsPlatformViewFactory())

        // MethodChannel for Flutter → Android calls
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getConnectivityStatus" -> result.success(getConnectivityStatus())
                "getBatteryLevel" -> result.success(getBatteryLevel())
                "hasNotificationListenerAccess" -> result.success(hasNotificationListenerAccess())
                "openNotificationAccessSettings" -> result.success(openNotificationAccessSettings())
                "openAccessibilitySettings" -> result.success(openAccessibilitySettings())
                "ensureStartupPermissions" -> result.success(ensureStartupPermissions())
                "launchVoiceAssistant" -> result.success(launchVoiceAssistant())
                "mediaCommand" -> {
                    val action = call.argument<String>("action")
                    if (action != null) {
                        result.success(
                            mediaCommand(action, call.argument<Number>("positionMs")?.toLong())
                        )
                    } else {
                        result.error("INVALID_ARG", "Missing action", null)
                    }
                }
                "getCurrentLocationInfo" -> getCurrentLocationInfo(result)
                "requestLocationPermission" -> result.success(requestLocationPermission())
                "startVehicleTrackingService" -> result.success(setVehicleTrackingServiceEnabled(true))
                "stopVehicleTrackingService" -> result.success(setVehicleTrackingServiceEnabled(false))
                "getVehicleTrackingDatabasePath" -> result.success(getVehicleTrackingDatabasePath())
                "updateVehicleTrackingSyncConfig" -> {
                    val endpoint = call.argument<String>("syncEndpoint") ?: ""
                    val token = call.argument<String>("accessToken") ?: ""
                    val vehicle = call.argument<Map<String, Any?>>("vehicle") ?: emptyMap()
                    result.success(updateVehicleTrackingSyncConfig(endpoint, token, vehicle))
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        result.success(launchApp(packageName))
                    } else {
                        result.error("INVALID_ARG", "Missing packageName", null)
                    }
                }
                "launchSplitScreen" -> {
                    val pkg1 = call.argument<String>("pkg1")
                    val pkg2 = call.argument<String>("pkg2")
                    if (pkg1 != null && pkg2 != null) {
                        result.success(launchSplitScreen(pkg1, pkg2))
                    } else {
                        result.error("INVALID_ARG", "Missing pkg1 or pkg2", null)
                    }
                }
                "getInstalledApps" -> getInstalledApps(result)
                "getAppIcon" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        getAppIcon(packageName, result)
                    } else {
                        result.error("INVALID_ARG", "Missing packageName", null)
                    }
                }
                "sendKeyEvent" -> {
                    val keyCode = call.argument<Int>("keyCode")
                    if (keyCode != null) {
                        result.success(sendKeyEvent(keyCode))
                    } else {
                        result.error("INVALID_ARG", "Missing keyCode", null)
                    }
                }
                "isEmbeddingSupported" -> {
                    result.success(VirtualDisplayEmbeddingCapability.getSupportInfo(this).supported)
                }
                "getEmbeddingInfo" -> {
                    val info = VirtualDisplayEmbeddingCapability.getSupportInfo(this)
                    result.success(
                        mapOf(
                            "supported" to info.supported,
                            "reason" to info.reason,
                            "apiLevel" to Build.VERSION.SDK_INT,
                        )
                    )
                }
                "launchMapsWithYoutubeOnTop" -> {
                    result.success(MultiWindowLauncher.launchMapsWithYoutubeOnTop(this))
                }
                "setScreenBrightness" -> {
                    val level = call.argument<Double>("level")
                    if (level != null) {
                        result.success(setScreenBrightness(level))
                    } else {
                        result.error("INVALID_ARG", "Missing level", null)
                    }
                }
                "getSystemReadiness" -> result.success(getSystemReadiness())
                "getScreenBrightness" -> result.success(getScreenBrightness())
                "isAutoBrightnessEnabled" -> result.success(isAutoBrightnessEnabled())
                "setAutoBrightness" -> {
                    val enabled = call.argument<Boolean>("enabled")
                    if (enabled != null) {
                        result.success(setAutoBrightness(enabled))
                    } else {
                        result.error("INVALID_ARG", "Missing enabled", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // EventChannel for Android → Flutter streams (connectivity)
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                registerConnectivityReceiver()
                registerAppPackageChangedReceiver()
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
                unregisterConnectivityReceiver()
                unregisterAppPackageChangedReceiver()
            }
        })

        // Navigation MethodChannel
        navMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAV_METHOD_CHANNEL)
        navMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "stopNavigation" -> {
                    result.success(stopNavigation())
                }
                "switchProvider" -> {
                    val pkg = call.argument<String>("packageName")
                    if (pkg != null) {
                        result.success(launchApp(pkg))
                    } else {
                        result.error("INVALID_ARG", "Missing packageName", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Navigation EventChannel
        navEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, NAV_EVENT_CHANNEL)
        navEventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                navEventSink = events
            }
            override fun onCancel(arguments: Any?) {
                navEventSink = null
            }
        })

        // Media EventChannel
        mediaEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_EVENT_CHANNEL)
        mediaEventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                mediaEventSink = events
                registerMediaSessionListener()
                // Send initial state
                mediaEventSink?.success(getMediaSessionMap())
            }
            override fun onCancel(arguments: Any?) {
                mediaEventSink = null
                unregisterMediaSessionListener()
            }
        })

        oauthChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.carlauncher/oauth")
        flushPendingOAuthCallback()
    }

    override fun onDestroy() {
        unregisterConnectivityReceiver()
        unregisterAppPackageChangedReceiver()
        unregisterMediaSessionListener()
        eventSink = null
        navEventSink = null
        mediaEventSink = null
        if (::methodChannel.isInitialized) methodChannel.setMethodCallHandler(null)
        if (::eventChannel.isInitialized) eventChannel.setStreamHandler(null)
        navMethodChannel?.setMethodCallHandler(null)
        navEventChannel?.setStreamHandler(null)
        mediaEventChannel?.setStreamHandler(null)
        oauthChannel?.setMethodCallHandler(null)
        oauthDeliveryHandler.removeCallbacksAndMessages(null)
        oauthDeliveryInFlight = false
        pendingOAuthCallback = null
        navMethodChannel = null
        navEventChannel = null
        mediaEventChannel = null
        oauthChannel = null
        super.onDestroy()
    }

    // ─── MediaSession ──────────────────────────────────────────────────

    private fun registerMediaSessionListener() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return
        unregisterMediaSessionListener()
        try {
            mediaSessionManager = getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager
            if (mediaSessionManager == null) return

            val componentName = android.content.ComponentName(this,NotificationListener::class.java)
            mediaControllerCallback = object : MediaController.Callback() {
                override fun onMetadataChanged(metadata: MediaMetadata?) {
                    mediaEventSink?.success(getMediaSessionMap())
                }
                override fun onPlaybackStateChanged(state: PlaybackState?) {
                    mediaEventSink?.success(getMediaSessionMap())
                }
                override fun onSessionDestroyed() {
                    selectActiveMediaController()
                }
            }
            activeSessionsChangedListener =
                MediaSessionManager.OnActiveSessionsChangedListener {
                    selectActiveMediaController(it.orEmpty())
                }
            mediaSessionManager!!.addOnActiveSessionsChangedListener(
                activeSessionsChangedListener!!,
                componentName,
            )
            selectActiveMediaController()
        } catch (_: Exception) {
            // MediaSession not available
        }
    }

    private fun selectActiveMediaController(controllers: List<MediaController>? = null) {
        val manager = mediaSessionManager ?: return
        val available = controllers ?: try {
            manager.getActiveSessions(
                android.content.ComponentName(this, NotificationListener::class.java)
            )
        } catch (_: Exception) {
            emptyList()
        }
        val previousPackage = activeMediaController?.packageName
        val selected = available.firstOrNull {
            it.playbackState?.state == PlaybackState.STATE_PLAYING
        } ?: available.firstOrNull {
            it.packageName == previousPackage
        } ?: available.firstOrNull()

        if (selected?.sessionToken != activeMediaController?.sessionToken) {
            try {
                activeMediaController?.let { controller ->
                    mediaControllerCallback?.let(controller::unregisterCallback)
                }
            } catch (_: Exception) {}
            activeMediaController = selected
            try {
                selected?.let { controller ->
                    mediaControllerCallback?.let(controller::registerCallback)
                }
            } catch (_: Exception) {}
        }
        mediaEventSink?.success(getMediaSessionMap())
    }

    private fun unregisterMediaSessionListener() {
        try {
            activeMediaController?.let { controller ->
                mediaControllerCallback?.let { callback ->
                    controller.unregisterCallback(callback)
                }
            }
        } catch (_: Exception) {}
        try {
            activeSessionsChangedListener?.let {
                mediaSessionManager?.removeOnActiveSessionsChangedListener(it)
            }
        } catch (_: Exception) {}
        activeMediaController = null
        mediaControllerCallback = null
        activeSessionsChangedListener = null
        mediaSessionManager = null
    }

    @Suppress("DEPRECATION")
    private fun getMediaSessionMap(): Map<String, Any> {
        val default = mapOf(
            "title" to "",
            "artist" to "",
            "album" to "",
            "albumArtUrl" to "",
            "durationMs" to 0,
            "positionMs" to 0,
            "state" to "none",
            "packageName" to "",
            "hasMedia" to false,
        )
        try {
            val controller = activeMediaController ?: return default
            val metadata = controller.metadata ?: return default
            val playbackState = controller.playbackState

            val title = metadata.getString(MediaMetadata.METADATA_KEY_TITLE) ?: ""
            val artist = metadata.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: ""
            val album = metadata.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: ""
            val duration = metadata.getLong(MediaMetadata.METADATA_KEY_DURATION)
            val stateCode = playbackState?.state ?: PlaybackState.STATE_NONE
            val position = playbackState?.position ?: 0L

            val stateStr = when (stateCode) {
                PlaybackState.STATE_PLAYING -> "playing"
                PlaybackState.STATE_PAUSED -> "paused"
                PlaybackState.STATE_STOPPED -> "stopped"
                else -> "none"
            }

            val hasMedia = title.isNotEmpty() || artist.isNotEmpty()

            return mapOf(
                "title" to title,
                "artist" to artist,
                "album" to album,
                "albumArtUrl" to "",
                "durationMs" to duration.toInt(),
                "positionMs" to position.toInt(),
                "state" to stateStr,
                "packageName" to (controller.packageName ?: ""),
                "hasMedia" to hasMedia,
            )
        } catch (_: Exception) {
            return default
        }
    }

    private fun mediaCommand(action: String, positionMs: Long?): Boolean {
        return try {
            if (activeMediaController == null) return false
            when (action) {
                "play" -> activeMediaController?.transportControls?.play()
                "pause" -> activeMediaController?.transportControls?.pause()
                "stop" -> activeMediaController?.transportControls?.stop()
                "next" -> activeMediaController?.transportControls?.skipToNext()
                "previous" -> activeMediaController?.transportControls?.skipToPrevious()
                "seekTo" -> activeMediaController?.transportControls?.seekTo(
                    positionMs ?: return false
                )
                else -> return false
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun hasNotificationListenerAccess(): Boolean {
        val componentName = android.content.ComponentName(this, NotificationListener::class.java)
        val enabled = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return enabled.split(':').any { it == componentName.flattenToString() }
    }

    private fun openNotificationAccessSettings(): Boolean {
        return try {
            startActivity(
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun hasInputAccessibilityAccess(): Boolean {
        val componentName = android.content.ComponentName(
            this,
            EmbeddedInputAccessibilityService::class.java,
        )
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        return enabled.split(':').any { it.equals(componentName.flattenToString(), ignoreCase = true) }
    }

    private fun openAccessibilitySettings(): Boolean {
        return try {
            startActivity(
                Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun launchVoiceAssistant(): Boolean {
        val intents = listOf(
            Intent(Intent.ACTION_VOICE_COMMAND),
            Intent(Intent.ACTION_ASSIST),
        )
        return intents.any { intent ->
            try {
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    // ─── Navigation State ─────────────────────────────────────────────

    // Google Maps exposes no public API for another app to stop active guidance.
    private fun stopNavigation(): Boolean = false

    private fun sendKeyEvent(keyCode: Int): Boolean {
        return try {
            // Note: On modern Android (API 23+), apps cannot inject key events
            // to other apps. This only works for system apps or with INJECT_EVENTS permission.
            // Best effort: use Instrumentation for same-app key events.
            val instrumentation = android.app.Instrumentation()
            instrumentation.sendKeyDownUpSync(keyCode)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun getConnectivityStatus(): Map<String, Any> {
        return ConnectivityStatusReader.read(this)
    }

    private fun getBatteryLevel(): Int {
        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        return bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
    }

    private fun requestLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        requestPermissions(
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ),
            LOCATION_PERMISSION_REQUEST,
        )
        return true
    }

    private fun ensureStartupPermissions(): Map<String, Any> {
        val missingRuntimePermissions = requiredRuntimePermissions().filter { permission ->
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED
        }
        if (missingRuntimePermissions.isNotEmpty()) {
            requestPermissions(
                missingRuntimePermissions.toTypedArray(),
                STARTUP_PERMISSION_REQUEST,
            )
        }

        val notificationAccess = hasNotificationListenerAccess()
        val accessibilityAccess = hasInputAccessibilityAccess()
        val openedAccessibilitySettings =
            missingRuntimePermissions.isEmpty() && !accessibilityAccess && openAccessibilitySettings()
        val openedNotificationAccessSettings =
            missingRuntimePermissions.isEmpty() &&
                accessibilityAccess &&
                !notificationAccess &&
                openNotificationAccessSettings()

        return mapOf(
            "requestedRuntimePermissions" to missingRuntimePermissions,
            "accessibilityInputGranted" to accessibilityAccess,
            "openedAccessibilitySettings" to openedAccessibilitySettings,
            "notificationListenerGranted" to notificationAccess,
            "openedNotificationAccessSettings" to openedNotificationAccessSettings,
            "privilegedPermissions" to mapOf(
                "addTrustedDisplay" to hasPermission("android.permission.ADD_TRUSTED_DISPLAY"),
                "injectEvents" to hasPermission("android.permission.INJECT_EVENTS"),
                "manageActivityTasks" to hasPermission("android.permission.MANAGE_ACTIVITY_TASKS"),
                "activityEmbedding" to hasPermission("android.permission.ACTIVITY_EMBEDDING"),
            ),
        )
    }

    private fun requiredRuntimePermissions(): List<String> {
        val permissions = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        return permissions
    }

    private fun openNextStartupPermissionSettings() {
        if (!hasInputAccessibilityAccess()) {
            openAccessibilitySettings()
            return
        }
        if (!hasNotificationListenerAccess()) {
            openNotificationAccessSettings()
        }
    }

    private fun hasPermission(permission: String): Boolean {
        return packageManager.checkPermission(permission, packageName) ==
            PackageManager.PERMISSION_GRANTED
    }

    @Suppress("MissingPermission", "DEPRECATION")
    private fun getCurrentLocationInfo(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED
        ) {
            result.success(mapOf("status" to "permission_required"))
            return
        }

        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = locationManager.getProviders(true)
        val lastLocation = providers
            .mapNotNull { provider ->
                try {
                    locationManager.getLastKnownLocation(provider)
                } catch (_: Exception) {
                    null
                }
            }
            .maxByOrNull(Location::getTime)

        val freshLocation = lastLocation?.takeIf {
            System.currentTimeMillis() - it.time <= 5 * 60 * 1000
        }
        if (freshLocation != null) {
            completeLocationInfo(freshLocation, result)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val provider = providers.firstOrNull { it == LocationManager.GPS_PROVIDER }
                ?: providers.firstOrNull()
            if (provider != null) {
                locationManager.getCurrentLocation(provider, null, mainExecutor) { location ->
                    if (location == null) {
                        result.success(mapOf("status" to "location_unavailable"))
                    } else {
                        completeLocationInfo(location, result)
                    }
                }
                return
            }
        }

        result.success(mapOf("status" to "location_unavailable"))
    }

    @Suppress("DEPRECATION")
    private fun completeLocationInfo(location: Location, result: MethodChannel.Result) {
        Thread {
            val address = try {
                if (Geocoder.isPresent()) {
                    Geocoder(this, Locale.getDefault())
                        .getFromLocation(location.latitude, location.longitude, 1)
                        ?.firstOrNull()
                } else {
                    null
                }
            } catch (_: Exception) {
                null
            }

            val displayName = listOfNotNull(
                address?.subLocality,
                address?.locality,
                address?.adminArea,
            ).distinct().joinToString(", ")

            val payload = mapOf(
                "status" to "ok",
                "displayName" to displayName,
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "source" to if (address == null) "gps" else "android_geocoder",
            )
            runOnUiThread { result.success(payload) }
        }.start()
    }


    private fun setVehicleTrackingServiceEnabled(enabled: Boolean): Boolean {
        val intent = Intent(this, VehicleTrackingService::class.java).apply {
            action = if (enabled) VehicleTrackingService.ACTION_START else VehicleTrackingService.ACTION_STOP
        }
        return try {
            if (enabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else if (enabled) {
                startService(intent)
            } else {
                startService(intent)
                stopService(intent)
            }
            true
        } catch (error: Throwable) {
            Log.w("MainActivity", "Unable to update vehicle tracking service", error)
            false
        }
    }

    private fun getVehicleTrackingDatabasePath(): String {
        return getDatabasePath(VehicleTrackingService.DATABASE_NAME).absolutePath
    }

    private fun updateVehicleTrackingSyncConfig(endpoint: String, token: String, vehicle: Map<String, Any?>): Boolean {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val vehicleJson = org.json.JSONObject(vehicle.filterValues {
                it?.toString()?.isNotBlank() == true
            }).toString()
            val editor = prefs.edit()
                .putString("flutter.vehicle_tracking_sync_endpoint", endpoint)
                .putString("flutter.vehicle_tracking_access_token", token)
            if (vehicleJson == "{}") {
                editor.remove("flutter.vehicle_profile")
            } else {
                editor.putString("flutter.vehicle_profile", vehicleJson)
            }
            editor.apply()
            true
        } catch (error: Throwable) {
            Log.w("MainActivity", "Unable to update vehicle tracking sync config", error)
            false
        }
    }

    // ── Screen Brightness ──────────────────────────────────────────────────

    @Suppress("DEPRECATION")
    private fun setScreenBrightness(level: Double): Boolean {
        return try {
            val clamped = level.coerceIn(0.0, 1.0)
            runOnUiThread {
                val params = window.attributes
                params.screenBrightness = clamped.toFloat()
                window.attributes = params
            }
            // Also write to system settings so it persists beyond the window.
            try {
                Settings.System.putInt(
                    contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS_MODE,
                    Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL,
                )
                val brightnessValue = (clamped * 255).toInt()
                Settings.System.putInt(
                    contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS,
                    brightnessValue,
                )
            } catch (_: SecurityException) {
                // WRITE_SETTINGS not granted — window-level change still applied.
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun getScreenBrightness(): Double {
        return try {
            val brightness = Settings.System.getInt(
                contentResolver,
                Settings.System.SCREEN_BRIGHTNESS,
            )
            (brightness / 255.0).coerceIn(0.0, 1.0)
        } catch (_: Exception) {
            // Fallback: read from window attributes
            val params = window.attributes
            val value = params.screenBrightness.toDouble().coerceIn(0.0, 1.0)
            if (value < 0.0) 0.85 else value
        }
    }

    @Suppress("DEPRECATION")
    private fun isAutoBrightnessEnabled(): Boolean {
        return try {
            val mode = Settings.System.getInt(
                contentResolver,
                Settings.System.SCREEN_BRIGHTNESS_MODE,
            )
            mode == Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC
        } catch (_: Exception) {
            true // default to auto if we can't read
        }
    }

    @Suppress("DEPRECATION")
    private fun setAutoBrightness(enabled: Boolean): Boolean {
        return try {
            Settings.System.putInt(
                contentResolver,
                Settings.System.SCREEN_BRIGHTNESS_MODE,
                if (enabled) Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC
                else Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL,
            )
            true
        } catch (_: SecurityException) {
            false
        }
    }

    /// Composite readiness check — called once at startup so Flutter can
    /// decide when it is safe to leave the splash screen.
    private fun getSystemReadiness(): Map<String, Any> {
        return mapOf(
            "nativeBridge" to true,
            "connectivity" to true,
            "deviceInfo" to true,
            "brightness" to true,
            "autoBrightness" to isAutoBrightnessEnabled(),
            "screenBrightness" to getScreenBrightness(),
            "bootUptimeSeconds" to (
                System.currentTimeMillis() -
                    android.os.SystemClock.elapsedRealtime()
                ) / 1000,
        )
    }

    private fun launchApp(packageName: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    /// Launch two apps in split-screen mode (Android 7.0+). Fallback path only.
    private fun launchSplitScreen(pkg1: String, pkg2: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false

        val intent1 = packageManager.getLaunchIntentForPackage(pkg1) ?: return false
        val intent2 = packageManager.getLaunchIntentForPackage(pkg2) ?: return false

        intent1.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_LAUNCH_ADJACENT or
                Intent.FLAG_ACTIVITY_MULTIPLE_TASK
        )
        intent2.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_LAUNCH_ADJACENT or
                Intent.FLAG_ACTIVITY_MULTIPLE_TASK
        )

        return try {
            startActivity(intent1)
            Handler(Looper.getMainLooper()).postDelayed({
                try { startActivity(intent2) } catch (_: Exception) {}
            }, 300)
            true
        } catch (e: Exception) {
            try { launchApp(pkg1) } catch (_: Exception) {}
            false
        }
    }

    private fun getAppIcon(packageName: String, result: MethodChannel.Result) {
        Thread {
            try {
                val drawable = packageManager.getApplicationIcon(packageName)
                val base64 = encodeDrawableToBase64(drawable)
                runOnUiThread { result.success(base64) }
            } catch (_: Exception) {
                runOnUiThread { result.success(null) }
            }
        }.start()
    }

    private fun encodeDrawableToBase64(drawable: Drawable, size: Int = 96): String {
        val bitmap = drawableToBitmap(drawable, size)
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
        return Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
    }

    private fun drawableToBitmap(drawable: Drawable, size: Int): Bitmap {
        if (drawable is BitmapDrawable) {
            val source = drawable.bitmap
            if (source != null && !source.isRecycled) {
                return Bitmap.createScaledBitmap(source, size, size, true)
            }
        }

        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            drawable is AdaptiveIconDrawable
        ) {
            drawable.background?.let { background ->
                background.setBounds(0, 0, size, size)
                background.draw(canvas)
            }
            drawable.foreground?.let { foreground ->
                foreground.setBounds(0, 0, size, size)
                foreground.draw(canvas)
            }
        } else {
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
        }

        return bitmap
    }

    private fun getInstalledApps(result: MethodChannel.Result) {
        // Run PackageManager query on a background thread to avoid ANR
        Thread {
            try {
                val intent = Intent(Intent.ACTION_MAIN, null).apply {
                    addCategory(Intent.CATEGORY_LAUNCHER)
                }
                val resolveInfos = packageManager.queryIntentActivities(intent, 0)
                val seenPackages = mutableSetOf<String>()
                val apps = resolveInfos
                    .sortedBy { it.loadLabel(packageManager).toString().lowercase() }
                    .mapNotNull { resolveInfo ->
                        val packageName = resolveInfo.activityInfo.packageName
                        if (!seenPackages.add(packageName)) return@mapNotNull null

                        val iconBase64 = try {
                            encodeDrawableToBase64(resolveInfo.loadIcon(packageManager))
                        } catch (_: Exception) {
                            ""
                        }

                        mapOf(
                            "packageName" to packageName,
                            "appName" to resolveInfo.loadLabel(packageManager).toString(),
                            "iconBase64" to iconBase64,
                        )
                    }
                runOnUiThread { result.success(apps) }
            } catch (_: Exception) {
                runOnUiThread { result.success(emptyList<Map<String, String>>()) }
            }
        }.start()
    }

    private var connectivityReceiver: BroadcastReceiver? = null

    private fun registerConnectivityReceiver() {
        unregisterConnectivityReceiver()
        connectivityReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                eventSink?.apply {
                    success(getConnectivityStatus())
                }
            }
        }
        val filter = IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION).apply {
            addAction(android.net.wifi.WifiManager.RSSI_CHANGED_ACTION)
            addAction(android.bluetooth.BluetoothAdapter.ACTION_STATE_CHANGED)
            addAction(android.bluetooth.BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(android.bluetooth.BluetoothDevice.ACTION_ACL_DISCONNECTED)
            addAction(Intent.ACTION_BATTERY_CHANGED)
        }
        registerReceiver(connectivityReceiver, filter)
    }

    private fun unregisterConnectivityReceiver() {
        connectivityReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
        }
        connectivityReceiver = null
    }

    private fun registerAppPackageChangedReceiver() {
        unregisterAppPackageChangedReceiver()
        appPackageChangedReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action ?: return
                val packageName = intent.data?.schemeSpecificPart ?: return
                if (action !in setOf(
                        Intent.ACTION_PACKAGE_ADDED,
                        Intent.ACTION_PACKAGE_REMOVED,
                        Intent.ACTION_PACKAGE_REPLACED,
                    )
                ) return

                eventSink?.success(
                    mapOf(
                        "type" to "app_package_changed",
                        "action" to action,
                        "packageName" to packageName,
                        "replacing" to intent.getBooleanExtra(Intent.EXTRA_REPLACING, false),
                    ),
                )
            }
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addDataScheme("package")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(appPackageChangedReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(appPackageChangedReceiver, filter)
        }
    }

    private fun unregisterAppPackageChangedReceiver() {
        appPackageChangedReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
        }
        appPackageChangedReceiver = null
    }
    companion object {
        private const val LOCATION_PERMISSION_REQUEST = 3102
        private const val STARTUP_PERMISSION_REQUEST = 3103
    }
}
