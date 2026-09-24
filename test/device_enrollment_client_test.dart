import 'dart:convert';

import 'package:car_launcher/core/auth/device_assertion_client.dart';
import 'package:car_launcher/core/auth/device_identity_service.dart';
import 'package:car_launcher/features/device/data/device_enrollment_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _base = 'https://dev-car-apis.202corp.com/vehicle-service/public-api/v1';

class _FakeIdentity extends DeviceIdentityService {
  final signedNonces = <String>[];
  final bootstrapKeys = <String>[];
  int assertionCalls = 0;
  int invalidations = 0;

  @override
  Future<DeviceIdentity> getIdentity() async => const DeviceIdentity(
        deviceId: 'device-key-id',
        publicKeyPem: '-----BEGIN PUBLIC KEY-----\nMFkwEw\n-----END PUBLIC KEY-----\n',
      );

  @override
  Future<String> signEnrollmentProof({
    required String nonce,
    required String bootstrapPrivateKeyPem,
  }) async {
    signedNonces.add(nonce);
    bootstrapKeys.add(bootstrapPrivateKeyPem);
    return 'PROOF';
  }

  @override
  Future<String> assertion() async {
    assertionCalls++;
    return 'jws-$assertionCalls';
  }

  @override
  void invalidateAssertion() => invalidations++;
}

Future<String> _loadAsset(String key) async => key.endsWith('.pem')
    ? '-----BEGIN CERTIFICATE-----\nMIIBcert\n-----END CERTIFICATE-----\n'
    : '-----BEGIN PRIVATE KEY-----\nMIGHkey\n-----END PRIVATE KEY-----\n';

void main() {
  group('DeviceEnrollmentClient', () {
    test('challenge → enroll: submits proof, device key and bootstrap chain', () async {
      final identity = _FakeIdentity();
      final requests = <http.Request>[];
      final client = DeviceEnrollmentClient(
        httpClient: MockClient((req) async {
          requests.add(req);
          if (req.url.path.endsWith('/enroll/challenge')) {
            expect(req.method, 'POST');
            return http.Response(
              jsonEncode({'nonce': 'NONCE-1', 'expiresAt': '2099-01-01T00:00:00Z'}),
              201,
            );
          }
          return http.Response(
            jsonEncode({'id': 'device-key-id', 'claimed': false, 'vehicleId': ''}),
            201,
          );
        }),
        publicApiBaseUrl: _base,
        identity: identity,
        loadAsset: _loadAsset,
      );

      final device = await client.enroll(
        name: 'samsung SM-X133',
        serialNumber: 'SER-1',
        model: 'SM-X133',
        firmwareVersion: '14',
        metadata: const {'board': 'bengal'},
      );

      expect(device.id, 'device-key-id');
      expect(device.claimed, isFalse);

      expect(requests[0].url.toString(), '$_base/devices/enroll/challenge');
      expect(requests[1].url.toString(), '$_base/devices/enroll');
      expect(identity.signedNonces, ['NONCE-1']);
      expect(identity.bootstrapKeys.single, contains('BEGIN PRIVATE KEY'));

      final body = jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(body['nonce'], 'NONCE-1');
      expect(body['proof'], 'PROOF');
      expect(body['devicePublicKey'], contains('BEGIN PUBLIC KEY'));
      expect(body['attestationCertChain'], hasLength(1));
      expect((body['attestationCertChain'] as List).single,
          contains('BEGIN CERTIFICATE'));
      expect(body['name'], 'samsung SM-X133');
      expect(body['serialNumber'], 'SER-1');
      expect(body['model'], 'SM-X133');
      expect(body['metadata'], {'board': 'bengal'});
    });

    test('throws when the challenge call fails', () async {
      final client = DeviceEnrollmentClient(
        httpClient: MockClient((req) async => http.Response('nope', 500)),
        publicApiBaseUrl: _base,
        identity: _FakeIdentity(),
        loadAsset: _loadAsset,
      );
      expect(client.enroll(), throwsStateError);
    });

    test('throws when enrollment is rejected', () async {
      final client = DeviceEnrollmentClient(
        httpClient: MockClient((req) async {
          if (req.url.path.endsWith('/enroll/challenge')) {
            return http.Response(jsonEncode({'nonce': 'N'}), 201);
          }
          return http.Response('bad attestation', 400);
        }),
        publicApiBaseUrl: _base,
        identity: _FakeIdentity(),
        loadAsset: _loadAsset,
      );
      expect(client.enroll(), throwsStateError);
    });
  });

  group('DeviceAssertionClient', () {
    test('attaches a fresh X-Device-Assertion to every request', () async {
      final identity = _FakeIdentity();
      final headers = <String?>[];
      final client = DeviceAssertionClient(
        inner: MockClient((req) async {
          headers.add(req.headers['X-Device-Assertion']);
          return http.Response('{}', 200);
        }),
        identity: identity,
      );

      await client.post(Uri.parse('$_base/devices/me/tracking-points'), body: '{}');
      await client.get(Uri.parse('$_base/devices/me'));

      expect(headers, ['jws-1', 'jws-2']);
      expect(identity.invalidations, 0);
    });

    test('drops the cached assertion on 401', () async {
      final identity = _FakeIdentity();
      final client = DeviceAssertionClient(
        inner: MockClient((req) async => http.Response('unauthorized', 401)),
        identity: identity,
      );

      await client.get(Uri.parse('$_base/devices/me'));

      expect(identity.invalidations, 1);
    });
  });
}
