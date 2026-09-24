import 'dart:convert';

import 'package:car_launcher/core/auth/device_assertion_client.dart';
import 'package:car_launcher/core/auth/device_identity_service.dart';
import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// A device record as returned by `vehicle-service`'s public API.
class EnrolledDevice {
  const EnrolledDevice({
    required this.id,
    required this.claimed,
    this.vehicleId = '',
  });

  final String id;
  final bool claimed;
  final String vehicleId;

  factory EnrolledDevice.fromJson(Map<String, dynamic> json) => EnrolledDevice(
    id: json['id'] as String? ?? '',
    claimed: json['claimed'] as bool? ?? false,
    vehicleId: json['vehicleId'] as String? ?? '',
  );
}

/// Runs the SELF_SIGNED_PKI enrollment handshake against
/// `POST /public-api/v1/devices/enroll{,/challenge}`:
///
/// 1. ask for a one-time `nonce`;
/// 2. read the per-install key identity from the native layer;
/// 3. sign the proof with the bundled app-bootstrap key;
/// 4. submit the bootstrap cert chain + device public key + proof.
///
/// Enrollment is idempotent server-side: re-enrolling the same key refreshes the
/// hardware fields and keeps any owner / vehicle link.
class DeviceEnrollmentClient {
  DeviceEnrollmentClient({
    required http.Client httpClient,
    required String publicApiBaseUrl,
    DeviceIdentityService? identity,
    http.Client? assertionClient,
    Future<String> Function(String assetKey)? loadAsset,
  }) : _http = httpClient,
       _baseUrl = publicApiBaseUrl.replaceAll(RegExp(r'/+$'), ''),
       _identity = identity ?? DeviceIdentityService.instance,
       _assertionClient =
           assertionClient ??
           DeviceAssertionClient(inner: http.Client(), identity: identity),
       _loadAsset = loadAsset ?? rootBundle.loadString;

  final http.Client _http;
  final String _baseUrl;
  final DeviceIdentityService _identity;
  final http.Client _assertionClient;
  final Future<String> Function(String assetKey) _loadAsset;

  static const _bootstrapKeyAsset = 'assets/attestation/app-bootstrap.key';
  static const _bootstrapCertAsset = 'assets/attestation/app-bootstrap.pem';

  Future<EnrolledDevice> enroll({
    String? name,
    String? serialNumber,
    String? imei,
    String? model,
    String? firmwareVersion,
    Map<String, dynamic>? metadata,
  }) async {
    final nonce = await _requestChallenge();
    final identity = await _identity.getIdentity();
    final bootstrapKeyPem = await _loadAsset(_bootstrapKeyAsset);
    final bootstrapCertPem = await _loadAsset(_bootstrapCertAsset);

    final proof = await _identity.signEnrollmentProof(
      nonce: nonce,
      bootstrapPrivateKeyPem: bootstrapKeyPem,
    );

    final body = <String, dynamic>{
      'nonce': nonce,
      'attestationCertChain': [bootstrapCertPem.trim()],
      'devicePublicKey': identity.publicKeyPem.trim(),
      'proof': proof,
      if (name != null && name.isNotEmpty) 'name': name,
      if (serialNumber != null && serialNumber.isNotEmpty)
        'serialNumber': serialNumber,
      if (imei != null && imei.isNotEmpty) 'imei': imei,
      if (model != null && model.isNotEmpty) 'model': model,
      if (firmwareVersion != null && firmwareVersion.isNotEmpty)
        'firmwareVersion': firmwareVersion,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    };

    final response = await _http.post(
      Uri.parse('$_baseUrl/devices/enroll'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Device enrollment failed: HTTP ${response.statusCode} ${response.body}',
      );
    }

    final device = EnrolledDevice.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    AppLogger.instance.i(
      'Device enrolled: ${device.id} (claimed=${device.claimed})',
      tag: 'DEVICE',
    );
    return device;
  }

  /// `GET /devices/me` under `X-Device-Assertion` — confirms the per-install key
  /// can authenticate the just-enrolled device.
  Future<EnrolledDevice> getSelf() async {
    final response = await _assertionClient.get(
      Uri.parse('$_baseUrl/devices/me'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Device self-check failed: HTTP ${response.statusCode} ${response.body}',
      );
    }
    return EnrolledDevice.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String> _requestChallenge() async {
    final response = await _http.post(
      Uri.parse('$_baseUrl/devices/enroll/challenge'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Enrollment challenge failed: HTTP ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final nonce = decoded['nonce'] as String?;
    if (nonce == null || nonce.isEmpty) {
      throw StateError('Enrollment challenge returned no nonce');
    }
    return nonce;
  }
}
