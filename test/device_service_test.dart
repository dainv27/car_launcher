import 'dart:convert';

import 'package:car_launcher/core/auth/device_identity_service.dart';
import 'package:car_launcher/features/device/data/device_enrollment_client.dart';
import 'package:car_launcher/features/device/data/device_service.dart';
import 'package:car_launcher/features/device/domain/device.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _testEndpoint =
    'https://car-apis.202corp.com/vehicle-service/client-api/v1';
const _publicEndpoint =
    'https://car-apis.202corp.com/vehicle-service/public-api/v1';

/// Deterministic stand-in for the native Keystore-backed identity.
class _FakeIdentity extends DeviceIdentityService {
  static const deviceId = 'dev-abc';
  int assertions = 0;

  @override
  Future<DeviceIdentity> getIdentity() async => const DeviceIdentity(
        deviceId: deviceId,
        publicKeyPem: '-----BEGIN PUBLIC KEY-----\nMFk=\n-----END PUBLIC KEY-----\n',
      );

  @override
  Future<String> signEnrollmentProof({
    required String nonce,
    required String bootstrapPrivateKeyPem,
  }) async =>
      'proof($nonce)';

  @override
  Future<String> assertion() async {
    assertions++;
    return 'header.payload.sig';
  }

  @override
  void invalidateAssertion() {}
}

DeviceEnrollmentClient _enrollmentClient(
  http.Client httpClient, {
  DeviceIdentityService? identity,
  http.Client? assertionClient,
}) =>
    DeviceEnrollmentClient(
      httpClient: httpClient,
      publicApiBaseUrl: _publicEndpoint,
      identity: identity ?? _FakeIdentity(),
      // Default the post-enrol self-check (`GET /devices/me`) onto the same mock
      // so it never touches the real network.
      assertionClient: assertionClient ?? httpClient,
      loadAsset: (key) async => key.endsWith('.pem')
          ? '-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----\n'
          : '-----BEGIN PRIVATE KEY-----\nMIGH\n-----END PRIVATE KEY-----\n',
    );

const _nativeChannel = MethodChannel('com.carlauncher/native');
const _deviceInfoChannel =
    MethodChannel('dev.fluttercommunity.plus/device_info');
const _androidIdChannel = MethodChannel('android_id');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_deviceInfoChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_androidIdChannel, null);
  });

  group('DeviceService', () {
    test('listDevices handles wrapped response', () async {
      final client = DeviceService(
        httpClient: MockClient((req) async => http.Response(
          jsonEncode({
            'devices': [
              {'id': 'dev-001', 'name': 'OBD'},
            ],
          }),
          200,
        )),
      );
      final result = await client.listDevices(endpoint: _testEndpoint);
      expect(result, hasLength(1));
      expect(result[0]['id'], 'dev-001');
    });

    void mockDeviceInfo() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_deviceInfoChannel, (call) async {
        if (call.method == 'getDeviceInfo') {
          return <String, dynamic>{
            'id': 'RQ3A.210805.001',
            'fingerprint': 'R8YY91N3TAF',
            'manufacturer': 'samsung',
            'model': 'SM-X133',
            'version': <String, dynamic>{'sdkInt': 36, 'release': '14'},
          };
        }
        return null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_androidIdChannel, (call) async {
        if (call.method == 'getId') return 'android-abc';
        return null;
      });
    }

    test('ensureDeviceRegistered runs the challenge → enroll handshake', () async {
      mockDeviceInfo();
      final paths = <String>[];
      final client = DeviceService(
        httpClient: MockClient((req) async => http.Response('', 200)),
        enrollmentClient: _enrollmentClient(
          MockClient((req) async {
            paths.add(req.url.path);
            if (req.url.path.endsWith('/enroll/challenge')) {
              return http.Response(
                jsonEncode({'nonce': 'n-1', 'expiresAt': '2099-01-01T00:00:00Z'}),
                201,
              );
            }
            return http.Response(
              jsonEncode({'id': 'dev-abc', 'claimed': false}),
              201,
            );
          }),
        ),
      );

      final device = await client.ensureDeviceRegistered();

      expect(device?.id, 'dev-abc');
      expect(device?.claimed, isFalse);
      expect(paths.take(2), [
        '/vehicle-service/public-api/v1/devices/enroll/challenge',
        '/vehicle-service/public-api/v1/devices/enroll',
      ]);
      // Post-enrol self-check reads the device back under X-Device-Assertion.
      expect(paths, contains('/vehicle-service/public-api/v1/devices/me'));
    });

    test('ensureDeviceRegistered enroll body carries the proof + device key', () async {
      mockDeviceInfo();
      Map<String, dynamic>? enrollBody;
      final client = DeviceService(
        httpClient: MockClient((req) async => http.Response('', 200)),
        enrollmentClient: _enrollmentClient(
          MockClient((req) async {
            if (req.url.path.endsWith('/enroll/challenge')) {
              return http.Response(jsonEncode({'nonce': 'n-42'}), 201);
            }
            enrollBody = jsonDecode(req.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({'id': 'dev-abc', 'claimed': false}),
              201,
            );
          }),
        ),
      );

      await client.ensureDeviceRegistered();

      expect(enrollBody!['nonce'], 'n-42');
      expect(enrollBody!['proof'], 'proof(n-42)');
      expect(enrollBody!['devicePublicKey'], contains('BEGIN PUBLIC KEY'));
      expect(enrollBody!['attestationCertChain'], isA<List<dynamic>>());
      expect(enrollBody!['model'], 'SM-X133');
      expect(enrollBody!['name'], 'samsung SM-X133');
    });

    test('ensureDeviceRegistered returns null when device info is unavailable',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_deviceInfoChannel, (call) async {
        throw PlatformException(code: 'unavailable');
      });
      final client = DeviceService(
        httpClient: MockClient((req) async => http.Response('', 200)),
        enrollmentClient: _enrollmentClient(
          MockClient((req) async => http.Response('should not be called', 500)),
        ),
      );
      expect(await client.ensureDeviceRegistered(), isNull);
    });

    test('createDevice returns existing device on 409', () async {
      final client = DeviceService(
        httpClient: MockClient((req) async {
          if (req.method == 'POST') {
            return http.Response('', 409);
          }
          return http.Response(
            jsonEncode({'device': {'id': 'existing-dev', 'name': 'Old'}}),
            200,
          );
        }),
      );
      final result = await client.createDevice(
        endpoint: _testEndpoint,
        device: const Device(id: 'existing-dev', name: 'New'),
      );
      expect(result.id, 'existing-dev');
    });
  });
}
