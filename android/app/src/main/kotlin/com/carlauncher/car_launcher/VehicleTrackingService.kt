package com.carlauncher.car_launcher

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

class VehicleTrackingService : Service(), LocationListener {
    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        trackingDatabase = VehicleTrackingDatabase(this)
        syncExecutor = Executors.newSingleThreadScheduledExecutor()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopTracking()
                stopSelf()
                return START_NOT_STICKY
            }
            else -> startTracking()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopTracking()
        syncExecutor.shutdownNow()
        super.onDestroy()
    }

    override fun onLocationChanged(location: Location) {
        appendPoint(location)
    }

    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

    override fun onProviderEnabled(provider: String) = Unit

    override fun onProviderDisabled(provider: String) = Unit

    private fun startTracking() {
        if (!hasLocationPermission()) {
            Log.w(TAG, "Location permission missing; cannot start tracking service")
            stopSelf()
            return
        }

        try {
            startForeground(NOTIFICATION_ID, buildNotification())
        } catch (error: SecurityException) {
            Log.w(TAG, "Unable to start foreground service for vehicle tracking", error)
            stopSelf()
            return
        }

        try {
            val provider = when {
                locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
                locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
                else -> null
            }
            if (provider == null) {
                Log.w(TAG, "No enabled location provider for vehicle tracking")
                return
            }
            locationManager.requestLocationUpdates(
                provider,
                LOCATION_INTERVAL_MS,
                LOCATION_MIN_DISTANCE_M,
                this,
            )
            locationManager.getLastKnownLocation(provider)?.let(::appendPoint)
            scheduleBackgroundSync()
            syncNow()
        } catch (error: SecurityException) {
            Log.w(TAG, "Unable to request vehicle tracking updates", error)
        }
    }

    private fun stopTracking() {
        try {
            locationManager.removeUpdates(this)
        } catch (_: Exception) {
        }
        syncSchedule?.cancel(false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun appendPoint(location: Location) {
        val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return

        val timestamp = System.currentTimeMillis()
        val id = "${timestamp * 1000}_${"%.6f".format(Locale.US, location.latitude)}_${"%.6f".format(Locale.US, location.longitude)}"
        try {
            val values = ContentValues().apply {
                put("id", id)
                put("latitude", location.latitude)
                put("longitude", location.longitude)
                put("display_name", "")
                put("timestamp", isoTimestamp(timestamp))
                put("created_at", isoTimestamp(timestamp))
            }
            trackingDatabase.writableDatabase.insertWithOnConflict(
                PENDING_TABLE,
                null,
                values,
                SQLiteDatabase.CONFLICT_IGNORE,
            )
            syncNow()
        } catch (error: Exception) {
            Log.w(TAG, "Unable to append vehicle tracking point", error)
        }
    }

    private fun scheduleBackgroundSync() {
        if (syncSchedule != null && syncSchedule?.isCancelled == false) return
        syncSchedule = syncExecutor.scheduleWithFixedDelay(
            { syncPendingPoints() },
            5,
            SYNC_INTERVAL_SECONDS,
            TimeUnit.SECONDS,
        )
    }

    private fun syncNow() {
        syncExecutor.execute { syncPendingPoints() }
    }

    private fun syncPendingPoints() {
        val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return
        val endpoint = prefs.getString(KEY_SYNC_ENDPOINT, "")?.trim().orEmpty()
        var token = prefs.getString(KEY_ACCESS_TOKEN, "")?.trim().orEmpty()
        val vehicle = prefs.getString(KEY_VEHICLE_PROFILE, "")?.trim().orEmpty()
        val vehicleId = vehicleIdFromProfile(vehicle)
        if (token.isEmpty() || vehicleId.isEmpty()) return

        try {
            while (true) {
                val batch = readPendingBatch()
                if (batch.isEmpty()) return
                val newToken = postBatchWithRefresh(endpoint, token, vehicleId, batch)
                if (newToken != null && newToken != token) {
                    token = newToken
                }
                markBatchSynced(batch)
            }
        } catch (error: Exception) {
            Log.w(TAG, "Vehicle tracking background sync failed", error)
        }
    }

    private fun readPendingBatch(): List<TrackedPoint> {
        val points = mutableListOf<TrackedPoint>()
        trackingDatabase.readableDatabase.query(
            PENDING_TABLE,
            arrayOf("id", "latitude", "longitude", "display_name", "timestamp"),
            null,
            null,
            null,
            null,
            "timestamp ASC",
            SYNC_BATCH_SIZE.toString(),
        ).use { cursor ->
            while (cursor.moveToNext()) {
                points.add(cursor.toTrackedPoint())
            }
        }
        return points
    }

    /// Post a batch of tracking points, automatically refreshing the bearer
    /// token on HTTP 401 and retrying once. Returns the (possibly refreshed)
    /// token so callers can persist it for subsequent batches.
    ///
    /// Returns null if no refresh was needed (original token is still valid).
    private fun postBatchWithRefresh(
        endpoint: String,
        token: String,
        vehicleId: String,
        points: List<TrackedPoint>,
    ): String? {
        val url = locationTrackingUrl(endpoint, vehicleId)
        var refreshedToken: String? = null
        points.forEachIndexed { index, point ->
            val payload = JSONObject()
                .put("latitude", point.latitude)
                .put("longitude", point.longitude)
                .put("eventTime", point.timestamp)
                .put(
                    "metadata",
                    JSONObject()
                        .put("clientPointId", point.id)
                        .put("displayName", point.displayName),
                )
            var currentToken = refreshedToken ?: token
            var responseCode = postPoint(url, payload, currentToken)

            // On 401, ask Flutter to refresh the token and retry this point.
            if (responseCode == 401) {
                val newToken = requestTokenRefresh(currentToken)
                if (newToken != null && newToken.isNotEmpty()) {
                    refreshedToken = newToken
                    currentToken = newToken
                    // Persist the new token immediately so future batches reuse it.
                    persistAccessToken(newToken)
                    responseCode = postPoint(url, payload, currentToken)
                }
            }

            if (responseCode < 200 || responseCode >= 300) {
                throw IllegalStateException("Tracking sync failed: HTTP $responseCode")
            }
        }
        return refreshedToken
    }

    /// POST a single tracking point. Returns the HTTP status code.
    private fun postPoint(url: String, payload: JSONObject, token: String): Int {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = HTTP_TIMEOUT_MS
            readTimeout = HTTP_TIMEOUT_MS
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Authorization", "Bearer $token")
        }
        try {
            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use {
                it.write(payload.toString())
            }
            return connection.responseCode
        } finally {
            connection.disconnect()
        }
    }

    /// Persist the refreshed access token to SharedPreferences.
    private fun persistAccessToken(token: String) {
        try {
            getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_ACCESS_TOKEN, token)
                .apply()
        } catch (error: Exception) {
            Log.w(TAG, "Unable to persist refreshed access token", error)
        }
    }

    /// Request a fresh access token from Flutter via the MethodChannel.
    ///
    /// This calls back into Flutter's KeycloakAuthRepository which owns the
    /// refresh token and the OIDC client credentials. Returns the new access
    /// token, or null if the refresh call failed.
    private fun requestTokenRefresh(oldToken: String): String? {
        return try {
            val mainHandler = Handler(Looper.getMainLooper())
            val latch = java.util.concurrent.CountDownLatch(1)
            val resultHolder = arrayOfNulls<String>(1)
            mainHandler.post {
                try {
                    val activity = MainActivity.instance
                    if (activity == null) {
                        Log.w(TAG, "MainActivity instance unavailable for token refresh")
                        latch.countDown()
                        return@post
                    }
                    activity.methodChannelForServices.invokeMethod(
                        "refreshVehicleToken",
                        oldToken,
                        object : MethodChannel.Result {
                            override fun success(result: Any?) {
                                resultHolder[0] = result?.toString()
                                latch.countDown()
                            }
                            override fun error(code: String, message: String?, details: Any?) {
                                Log.w(TAG, "Token refresh failed: $code — $message")
                                latch.countDown()
                            }
                            override fun notImplemented() {
                                Log.w(TAG, "refreshVehicleToken not implemented on Flutter side")
                                latch.countDown()
                            }
                        },
                    )
                } catch (error: Exception) {
                    Log.w(TAG, "Unable to invoke token refresh", error)
                    latch.countDown()
                }
            }
            // Block the background thread for up to 30s for Flutter to respond.
            latch.await(30, java.util.concurrent.TimeUnit.SECONDS)
            resultHolder[0]
        } catch (error: Exception) {
            Log.w(TAG, "Token refresh request failed", error)
            null
        }
    }

    private fun vehicleIdFromProfile(vehicle: String): String {
        if (vehicle.isEmpty()) return ""
        return try {
            val json = JSONObject(vehicle)
            json.optString("vehicleId").ifBlank { json.optString("id") }
        } catch (_: Exception) {
            ""
        }
    }

    private fun locationTrackingUrl(endpoint: String, vehicleId: String): String {
        val base = vehicleServiceBase(endpoint)
        return "${base}/vehicles/${vehicleId}/tracking-points"
    }

    private fun vehicleServiceBase(endpoint: String): String {
        if (endpoint.isBlank()) return DEFAULT_VEHICLE_SERVICE_BASE
        val trimmed = endpoint.trimEnd('/')
        val serviceMarker = "/vehicle-service"
        val serviceIndex = trimmed.indexOf(serviceMarker)
        if (serviceIndex >= 0) {
            val versionIndex = trimmed.indexOf("/v1", serviceIndex)
            if (versionIndex >= 0) {
                return trimmed.substring(0, versionIndex + "/v1".length)
            }
            return trimmed.substring(0, serviceIndex + serviceMarker.length) + "/client-api/v1"
        }
        return trimmed
    }

    private fun markBatchSynced(points: List<TrackedPoint>) {
        val syncedAt = isoTimestamp(System.currentTimeMillis())
        trackingDatabase.writableDatabase.beginTransaction()
        try {
            points.forEach { point ->
                val values = ContentValues().apply {
                    put("id", point.id)
                    put("latitude", point.latitude)
                    put("longitude", point.longitude)
                    put("display_name", point.displayName)
                    put("timestamp", point.timestamp)
                    put("synced_at", syncedAt)
                }
                trackingDatabase.writableDatabase.insertWithOnConflict(
                    SYNCED_TABLE,
                    null,
                    values,
                    SQLiteDatabase.CONFLICT_REPLACE,
                )
                trackingDatabase.writableDatabase.delete(
                    PENDING_TABLE,
                    "id = ?",
                    arrayOf(point.id),
                )
            }
            trimSyncedHistory()
            trackingDatabase.writableDatabase.setTransactionSuccessful()
        } finally {
            trackingDatabase.writableDatabase.endTransaction()
        }
    }

    private fun trimSyncedHistory() {
        trackingDatabase.writableDatabase.execSQL(
            """
            DELETE FROM $SYNCED_TABLE
            WHERE id IN (
                SELECT id FROM $SYNCED_TABLE
                ORDER BY timestamp ASC
                LIMIT (
                    SELECT CASE
                        WHEN COUNT(*) > $MAX_SYNCED_POINTS THEN COUNT(*) - $MAX_SYNCED_POINTS
                        ELSE 0
                    END
                    FROM $SYNCED_TABLE
                )
            )
            """.trimIndent(),
        )
    }

    private fun hasLocationPermission(): Boolean {
        val locationGranted = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val fgsLocationGranted = checkSelfPermission(Manifest.permission.FOREGROUND_SERVICE_LOCATION) == PackageManager.PERMISSION_GRANTED
        return locationGranted && fgsLocationGranted
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Vehicle tracking",
            NotificationManager.IMPORTANCE_LOW,
        )
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("Vehicle tracking active")
            .setContentText("Recording vehicle location offline for sync")
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    private fun isoTimestamp(millis: Long): String {
        return isoFormat.get()!!.format(Date(millis))
    }

    private lateinit var locationManager: LocationManager
    private lateinit var trackingDatabase: VehicleTrackingDatabase
    private lateinit var syncExecutor: java.util.concurrent.ScheduledExecutorService
    private var syncSchedule: ScheduledFuture<*>? = null

    private data class TrackedPoint(
        val id: String,
        val latitude: Double,
        val longitude: Double,
        val displayName: String,
        val timestamp: String,
    )

    private fun Cursor.toTrackedPoint(): TrackedPoint {
        return TrackedPoint(
            id = getString(0),
            latitude = getDouble(1),
            longitude = getDouble(2),
            displayName = getString(3) ?: "",
            timestamp = getString(4),
        )
    }

    private class VehicleTrackingDatabase(context: Context) : SQLiteOpenHelper(
        context,
        DATABASE_NAME,
        null,
        DATABASE_VERSION,
    ) {
        override fun onCreate(db: SQLiteDatabase) {
            createSchema(db)
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            createSchema(db)
        }

        override fun onOpen(db: SQLiteDatabase) {
            super.onOpen(db)
            createSchema(db)
        }

        private fun createSchema(db: SQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS $PENDING_TABLE (
                    id TEXT PRIMARY KEY,
                    latitude REAL NOT NULL,
                    longitude REAL NOT NULL,
                    display_name TEXT NOT NULL DEFAULT '',
                    timestamp TEXT NOT NULL,
                    created_at TEXT NOT NULL
                )
                """.trimIndent(),
            )
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS $SYNCED_TABLE (
                    id TEXT PRIMARY KEY,
                    latitude REAL NOT NULL,
                    longitude REAL NOT NULL,
                    display_name TEXT NOT NULL DEFAULT '',
                    timestamp TEXT NOT NULL,
                    synced_at TEXT NOT NULL
                )
                """.trimIndent(),
            )
            db.execSQL("CREATE INDEX IF NOT EXISTS idx_pending_timestamp ON $PENDING_TABLE(timestamp)")
            db.execSQL("CREATE INDEX IF NOT EXISTS idx_synced_timestamp ON $SYNCED_TABLE(timestamp)")
        }
    }

    companion object {
        const val ACTION_START = "com.carlauncher.car_launcher.vehicle_tracking.START"
        const val ACTION_STOP = "com.carlauncher.car_launcher.vehicle_tracking.STOP"
        private const val TAG = "VehicleTrackingService"
        private const val CHANNEL_ID = "vehicle_tracking"
        private const val NOTIFICATION_ID = 4208
        private const val LOCATION_INTERVAL_MS = 15_000L
        private const val LOCATION_MIN_DISTANCE_M = 5f
        private const val SYNC_INTERVAL_SECONDS = 30L
        private const val SYNC_BATCH_SIZE = 100
        private const val MAX_SYNCED_POINTS = 10000
        private const val HTTP_TIMEOUT_MS = 15_000
        private const val DEFAULT_VEHICLE_SERVICE_BASE = "https://car-apis.202corp.com/vehicle-service/client-api/v1"
        const val DATABASE_NAME = "vehicle_tracking.sqlite"
        private const val DATABASE_VERSION = 1
        private const val PENDING_TABLE = "pending_points"
        private const val SYNCED_TABLE = "synced_points"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val KEY_ENABLED = "flutter.vehicle_tracking_enabled"
        private const val KEY_SYNC_ENDPOINT = "flutter.vehicle_tracking_sync_endpoint"
        private const val KEY_ACCESS_TOKEN = "flutter.vehicle_tracking_access_token"
        private const val KEY_VEHICLE_PROFILE = "flutter.vehicle_profile"
        private val isoFormat = ThreadLocal.withInitial {
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }
        }
    }
}
