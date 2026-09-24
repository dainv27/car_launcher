import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:flutter/services.dart';

/// The per-install device identity as attested to `vehicle-service`.
class DeviceIdentity {
  const DeviceIdentity({required this.deviceId, required this.publicKeyPem});

  /// `base64url(SHA-256(SubjectPublicKeyInfo))` — the backend device id and the
  /// `kid`/`sub` of every device assertion.
  final String deviceId;

  /// PEM `SubjectPublicKeyInfo` of the per-install signing key.
  final String publicKeyPem;
}

/// Bridges the native `com.carlauncher/device_auth` channel: an Android Keystore
/// EC P-256 key that the backend attests at enrollment and that signs every
/// `X-Device-Assertion`.
///
/// Assertions are minted natively and cached until shortly before they expire so
/// a burst of requests reuses one JWS.
class DeviceIdentityService {
  DeviceIdentityService();

  static final DeviceIdentityService instance = DeviceIdentityService();

  static const MethodChannel _channel = MethodChannel('com.carlauncher/device_auth');

  static const String assertionAudience = 'vehicle-service';
  static const Duration _assertionTtl = Duration(minutes: 4);
  static const Duration _assertionRefreshLead = Duration(seconds: 60);

  DeviceIdentity? _identity;
  String? _cachedAssertion;
  DateTime? _cachedAssertionExpiry;

  /// The per-install identity, generating the Keystore key on first call.
  Future<DeviceIdentity> getIdentity() async {
    final cached = _identity;
    if (cached != null) return cached;

    final raw = await _channel.invokeMapMethod<String, dynamic>('getDeviceIdentity');
    if (raw == null) {
      throw StateError('device_auth.getDeviceIdentity returned null');
    }
    final identity = DeviceIdentity(
      deviceId: raw['deviceId'] as String,
      publicKeyPem: raw['publicKeyPem'] as String,
    );
    _identity = identity;
    return identity;
  }

  /// `base64(SHA256withECDSA)` over `nonce_ascii ‖ devicePublicKeyDer`, signed
  /// with the app-bootstrap key — the SELF_SIGNED_PKI enrollment proof.
  Future<String> signEnrollmentProof({
    required String nonce,
    required String bootstrapPrivateKeyPem,
  }) async {
    final proof = await _channel.invokeMethod<String>('signEnrollmentProof', {
      'nonce': nonce,
      'bootstrapPrivateKeyPem': bootstrapPrivateKeyPem,
    });
    if (proof == null || proof.isEmpty) {
      throw StateError('device_auth.signEnrollmentProof returned empty');
    }
    return proof;
  }

  /// A compact ES256 JWS for the `X-Device-Assertion` header, reused until it is
  /// within [_assertionRefreshLead] of expiry.
  Future<String> assertion() async {
    final now = DateTime.now();
    final cached = _cachedAssertion;
    final expiry = _cachedAssertionExpiry;
    if (cached != null &&
        expiry != null &&
        now.isBefore(expiry.subtract(_assertionRefreshLead))) {
      return cached;
    }

    final jws = await _channel.invokeMethod<String>('mintDeviceAssertion', {
      'audience': assertionAudience,
      'ttlSeconds': _assertionTtl.inSeconds,
    });
    if (jws == null || jws.isEmpty) {
      throw StateError('device_auth.mintDeviceAssertion returned empty');
    }
    _cachedAssertion = jws;
    _cachedAssertionExpiry = now.add(_assertionTtl);
    AppLogger.instance.d('Minted device assertion', tag: 'DEVICE_AUTH');
    return jws;
  }

  /// Drops the cached assertion so the next request mints a fresh one.
  void invalidateAssertion() {
    _cachedAssertion = null;
    _cachedAssertionExpiry = null;
  }
}
