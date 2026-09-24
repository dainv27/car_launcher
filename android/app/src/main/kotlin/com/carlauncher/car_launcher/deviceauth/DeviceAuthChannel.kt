package com.carlauncher.car_launcher.deviceauth

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter bridge to [DeviceKeyStore] for device-attestation auth against the
 * `vehicle-service` public API.
 *
 * The bootstrap private key is a dev credential shared by every install (see
 * `assets/attestation/`), so it is passed in from Dart rather than kept here.
 */
class DeviceAuthChannel(messenger: BinaryMessenger) {

    private val channel = MethodChannel(messenger, CHANNEL).also {
        it.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getDeviceIdentity" -> result.success(DeviceKeyStore.identity())
                    "signEnrollmentProof" -> result.success(
                        DeviceKeyStore.signEnrollmentProof(
                            call.argument<String>("nonce")!!,
                            call.argument<String>("bootstrapPrivateKeyPem")!!,
                        ),
                    )
                    "mintDeviceAssertion" -> result.success(
                        DeviceKeyStore.mintAssertion(
                            call.argument<String>("audience") ?: DeviceKeyStore.AUDIENCE,
                            (call.argument<Number>("ttlSeconds")
                                ?: DeviceKeyStore.DEFAULT_TTL_SECONDS).toLong(),
                        ),
                    )
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("DEVICE_AUTH_ERROR", e.message, e.stackTraceToString())
            }
        }
    }

    fun dispose() = channel.setMethodCallHandler(null)

    companion object {
        const val CHANNEL = "com.carlauncher/device_auth"
    }
}
