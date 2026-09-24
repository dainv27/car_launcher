package com.carlauncher.car_launcher.deviceauth

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.security.spec.PKCS8EncodedKeySpec
import java.util.UUID

/**
 * Per-install device identity for the `vehicle-service` public API.
 *
 *  * holds an EC P-256 signing key in the Android Keystore
 *    (`car_launcher_device_key`) — the key the backend attests at enrollment
 *    and the one that signs every `X-Device-Assertion`;
 *  * signs the SELF_SIGNED_PKI enrollment proof with the app-bootstrap key
 *    (`SHA256withECDSA`, DER, standard base64 — matches `SelfSignedPkiVerifier`);
 *  * mints the `X-Device-Assertion` compact JWS (ES256, JOSE R‖S signature —
 *    matches jose4j in `DeviceAssertionVerifier`).
 *
 * Shared by [DeviceAuthChannel] (Flutter) and the background tracking service,
 * which must authenticate uploads while the Flutter UI is not running.
 */
object DeviceKeyStore {
    const val AUDIENCE = "vehicle-service"
    const val ASSERTION_HEADER = "X-Device-Assertion"
    const val DEFAULT_TTL_SECONDS = 240L

    private const val KEY_ALIAS = "car_launcher_device_key"
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"

    @Synchronized
    private fun deviceKeyEntry(): KeyStore.PrivateKeyEntry {
        val ks = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (ks.getEntry(KEY_ALIAS, null) as? KeyStore.PrivateKeyEntry)?.let { return it }

        val spec = KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_SIGN)
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .build()
        KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, ANDROID_KEYSTORE).apply {
            initialize(spec)
            generateKeyPair()
        }
        return ks.getEntry(KEY_ALIAS, null) as KeyStore.PrivateKeyEntry
    }

    /** `deviceId` = base64url(SHA-256(SPKI DER)), plus the public key PEM. */
    fun identity(): Map<String, String> {
        val spki = deviceKeyEntry().certificate.publicKey.encoded
        return mapOf(
            "deviceId" to base64Url(sha256(spki)),
            "publicKeyPem" to pem("PUBLIC KEY", spki),
        )
    }

    fun signEnrollmentProof(nonce: String, bootstrapPrivateKeyPem: String): String {
        val spki = deviceKeyEntry().certificate.publicKey.encoded
        val signed = nonce.toByteArray(Charsets.US_ASCII) + spki
        val sig = Signature.getInstance("SHA256withECDSA").apply {
            initSign(parsePkcs8EcPrivateKey(bootstrapPrivateKeyPem))
            update(signed)
        }.sign()
        // DER + standard base64 — matches SelfSignedPkiVerifier.verify.
        return Base64.encodeToString(sig, Base64.NO_WRAP)
    }

    fun mintAssertion(
        audience: String = AUDIENCE,
        ttlSeconds: Long = DEFAULT_TTL_SECONDS,
    ): String {
        val entry = deviceKeyEntry()
        val deviceId = base64Url(sha256(entry.certificate.publicKey.encoded))
        val now = System.currentTimeMillis() / 1000L

        val header = JSONObject(linkedMapOf("alg" to "ES256", "typ" to "JWT", "kid" to deviceId))
        val payload = JSONObject(
            linkedMapOf(
                "sub" to deviceId,
                "aud" to audience,
                "iat" to now,
                "exp" to now + ttlSeconds,
                "jti" to UUID.randomUUID().toString(),
            ),
        )
        val signingInput =
            base64Url(header.toString().toByteArray(Charsets.UTF_8)) + "." +
                base64Url(payload.toString().toByteArray(Charsets.UTF_8))

        val der = Signature.getInstance("SHA256withECDSA").apply {
            initSign(entry.privateKey)
            update(signingInput.toByteArray(Charsets.US_ASCII))
        }.sign()
        return signingInput + "." + base64Url(derToJose(der, 32))
    }

    private fun sha256(bytes: ByteArray) = MessageDigest.getInstance("SHA-256").digest(bytes)

    private fun base64Url(bytes: ByteArray): String =
        Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)

    private fun pem(label: String, der: ByteArray): String {
        val b64 = Base64.encodeToString(der, Base64.NO_WRAP)
        val body = b64.chunked(64).joinToString("\n")
        return "-----BEGIN $label-----\n$body\n-----END $label-----\n"
    }

    private fun parsePkcs8EcPrivateKey(pem: String): PrivateKey {
        val der = Base64.decode(
            pem.replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .replace(Regex("\\s"), ""),
            Base64.DEFAULT,
        )
        return KeyFactory.getInstance("EC").generatePrivate(PKCS8EncodedKeySpec(der))
    }

    /**
     * Convert a DER-encoded ECDSA signature (SEQUENCE { INTEGER r, INTEGER s })
     * to the fixed-width JOSE R‖S form jose4j expects for ES256.
     */
    private fun derToJose(der: ByteArray, partLen: Int): ByteArray {
        var offset = 0
        require(der[offset++].toInt() == 0x30) { "not a DER sequence" }
        if (der[offset].toInt() and 0xff == 0x81) offset++ // long-form length byte
        offset++ // sequence length

        require(der[offset++].toInt() == 0x02) { "expected INTEGER r" }
        val rLen = der[offset++].toInt()
        val r = der.copyOfRange(offset, offset + rLen)
        offset += rLen

        require(der[offset++].toInt() == 0x02) { "expected INTEGER s" }
        val sLen = der[offset++].toInt()
        val s = der.copyOfRange(offset, offset + sLen)

        return leftPad(stripLeadingZeros(r), partLen) + leftPad(stripLeadingZeros(s), partLen)
    }

    private fun stripLeadingZeros(b: ByteArray): ByteArray {
        var i = 0
        while (i < b.size - 1 && b[i].toInt() == 0) i++
        return b.copyOfRange(i, b.size)
    }

    private fun leftPad(b: ByteArray, len: Int): ByteArray {
        if (b.size == len) return b
        require(b.size <= len) { "integer longer than $len bytes" }
        return ByteArray(len - b.size) + b
    }
}
