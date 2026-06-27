package com.carlauncher.car_launcher

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.telephony.TelephonyManager

object ConnectivityStatusReader {
    @Suppress("DEPRECATION", "MissingPermission")
    fun read(context: Context): Map<String, Any> {
        val connectivity =
            context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val capabilities = connectivity.getNetworkCapabilities(connectivity.activeNetwork)
        val wifi = capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        val cellular = capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true
        val bluetoothNetwork =
            capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) == true
        val vpn = capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
        val validated =
            capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true

        val wifiManager =
            context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val wifiRssi = if (wifi) wifiManager.connectionInfo?.rssi ?: Int.MIN_VALUE else Int.MIN_VALUE
        val wifiLevel =
            if (wifiRssi == Int.MIN_VALUE) -1 else WifiManager.calculateSignalLevel(wifiRssi, 5)

        val telephony =
            context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        val cellularLevel = if (cellular && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                telephony.signalStrength?.level ?: -1
            } catch (_: SecurityException) {
                -1
            }
        } else {
            -1
        }
        val cellularOperator = try {
            telephony.networkOperatorName?.takeIf { it.isNotBlank() } ?: ""
        } catch (_: SecurityException) {
            ""
        }
        val cellularNetworkType = try {
            networkTypeName(telephony.dataNetworkType)
        } catch (_: SecurityException) {
            "Unknown"
        }

        val adapter =
            (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
        val bluetoothEnabled = adapter?.isEnabled == true
        val bluetoothConnected = bluetoothEnabled && canReadBluetooth(context) && adapter != null &&
            listOf(
                android.bluetooth.BluetoothProfile.HEADSET,
                android.bluetooth.BluetoothProfile.A2DP,
                android.bluetooth.BluetoothProfile.GATT,
            ).any { profile ->
                try {
                    adapter.getProfileConnectionState(profile) ==
                        android.bluetooth.BluetoothProfile.STATE_CONNECTED
                } catch (_: SecurityException) {
                    false
                }
            }

        val battery =
            (context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager)
                .getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)

        return mapOf(
            "wifi" to wifi,
            "wifiRssi" to wifiRssi,
            "wifiLevel" to wifiLevel,
            "cellular" to cellular,
            "cellularLevel" to cellularLevel,
            "cellularOperator" to cellularOperator,
            "cellularNetworkType" to cellularNetworkType,
            "bluetoothNetwork" to bluetoothNetwork,
            "bluetoothEnabled" to bluetoothEnabled,
            "bluetoothConnected" to bluetoothConnected,
            "vpn" to vpn,
            "validated" to validated,
            "batteryLevel" to battery,
        )
    }

    private fun canReadBluetooth(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED

    private fun networkTypeName(type: Int): String {
        return when (type) {
            TelephonyManager.NETWORK_TYPE_GPRS,
            TelephonyManager.NETWORK_TYPE_EDGE,
            TelephonyManager.NETWORK_TYPE_CDMA,
            TelephonyManager.NETWORK_TYPE_1xRTT,
            TelephonyManager.NETWORK_TYPE_IDEN,
            TelephonyManager.NETWORK_TYPE_GSM,
            -> "2G"
            TelephonyManager.NETWORK_TYPE_UMTS,
            TelephonyManager.NETWORK_TYPE_EVDO_0,
            TelephonyManager.NETWORK_TYPE_EVDO_A,
            TelephonyManager.NETWORK_TYPE_HSDPA,
            TelephonyManager.NETWORK_TYPE_HSUPA,
            TelephonyManager.NETWORK_TYPE_HSPA,
            TelephonyManager.NETWORK_TYPE_EVDO_B,
            TelephonyManager.NETWORK_TYPE_EHRPD,
            TelephonyManager.NETWORK_TYPE_HSPAP,
            TelephonyManager.NETWORK_TYPE_TD_SCDMA,
            -> "3G"
            TelephonyManager.NETWORK_TYPE_LTE,
            TelephonyManager.NETWORK_TYPE_IWLAN,
            -> "LTE"
            TelephonyManager.NETWORK_TYPE_NR -> "5G"
            else -> "Unknown"
        }
    }
}
