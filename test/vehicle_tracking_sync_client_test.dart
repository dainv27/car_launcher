import 'dart:convert';

import 'package:car_launcher/core/auth/device_identity_service.dart';
import 'package:car_launcher/features/vehicle/data/device_enrollment_client.dart';
import 'package:car_launcher/shared/data/device_service.dart';
import 'package:car_launcher/shared/data/location_service.dart';
import 'package:car_launcher/features/vehicle/domain/device.dart';
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

  group('VehicleTrackingSyncClient', () {
    test('sync throws if vehicleId is empty', () async {
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response('', 200)),
      );
      expect(
        client.sync(
          endpoint: _testEndpoint,
          points: [],
          vehicle: const VehicleProfile(vehicleId: ''),
        ),
        throwsStateError,
      );
    });

    test('sync throws on non-2xx response', () async {
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response('', 200)),
        pushClient: MockClient((req) async => http.Response('error', 500)),
        publicApiBaseUrl: _publicEndpoint,
      );
      final point = VehicleTrackPoint(
        id: 'p-1',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026),
      );
      expect(
        client.sync(
          endpoint: _testEndpoint,
          points: [point],
          vehicle: const VehicleProfile(vehicleId: 'car-001'),
        ),
        throwsStateError,
      );
    });

    test('sync throws a linkage error on 409', () async {
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response('', 200)),
        pushClient: MockClient((req) async => http.Response('', 409)),
        publicApiBaseUrl: _publicEndpoint,
      );
      expect(
        client.sync(
          endpoint: _testEndpoint,
          points: [
            VehicleTrackPoint(
              id: 'p-1',
              latitude: 10,
              longitude: 106,
              timestamp: DateTime.utc(2026),
            ),
          ],
          vehicle: const VehicleProfile(vehicleId: 'car-001'),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('not linked to a vehicle'),
          ),
        ),
      );
    });

    test('sync posts each point to the device public tracking endpoint', () async {
      final urls = <String>[];
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response('', 200)),
        pushClient: MockClient((req) async {
          urls.add(req.url.toString());
          return http.Response('{}', 201);
        }),
        publicApiBaseUrl: _publicEndpoint,
      );
      await client.sync(
        endpoint: _testEndpoint,
        points: [
          VehicleTrackPoint(
            id: 'p-1',
            latitude: 10,
            longitude: 106,
            timestamp: DateTime.utc(2026),
          ),
        ],
        vehicle: const VehicleProfile(vehicleId: 'car-001'),
      );
      expect(urls, ['$_publicEndpoint/devices/me/tracking-points']);
    });

    test('getLatestTrackingPoint throws on non-2xx/204 response', () async {
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response('error', 403)),
      );
      expect(
        client.getLatestTrackingPoint(
          endpoint: _testEndpoint,
          deviceId: 'dev-001',
        ),
        throwsStateError,
      );
    });

    test('listTrackingPoints throws on non-2xx response', () async {
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response('error', 500)),
      );
      expect(
        client.listTrackingPoints(
          endpoint: _testEndpoint,
          deviceId: 'dev-001',
        ),
        throwsStateError,
      );
    });

    test('listTrackingPoints handles wrapped response shapes', () async {
      // Test "content" wrapper
      final contentClient = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response(
          jsonEncode({
            'content': [
              {
                'id': 'p-1',
                'latitude': 10.0,
                'longitude': 106.0,
                'eventTime': '2026-06-22T12:00:00.000Z',
              },
            ],
          }),
          200,
        )),
      );
      final contentResult = await contentClient.listTrackingPoints(
        endpoint: _testEndpoint,
        deviceId: 'dev-001',
      );
      expect(contentResult, hasLength(1));

      // Test "data" wrapper
      final dataClient = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'p-2',
                'latitude': 11.0,
                'longitude': 107.0,
                'eventTime': '2026-06-22T13:00:00.000Z',
              },
            ],
          }),
          200,
        )),
      );
      final dataResult = await dataClient.listTrackingPoints(
        endpoint: _testEndpoint,
        deviceId: 'dev-001',
      );
      expect(dataResult, hasLength(1));

      // Test "items" wrapper
      final itemsClient = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'p-3',
                'latitude': 12.0,
                'longitude': 108.0,
                'eventTime': '2026-06-22T14:00:00.000Z',
              },
            ],
          }),
          200,
        )),
      );
      final itemsResult = await itemsClient.listTrackingPoints(
        endpoint: _testEndpoint,
        deviceId: 'dev-001',
      );
      expect(itemsResult, hasLength(1));

      // Test "trackingPoints" wrapper
      final tpClient = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response(
          jsonEncode({
            'trackingPoints': [
              {
                'id': 'p-4',
                'latitude': 13.0,
                'longitude': 109.0,
                'eventTime': '2026-06-22T15:00:00.000Z',
              },
            ],
          }),
          200,
        )),
      );
      final tpResult = await tpClient.listTrackingPoints(
        endpoint: _testEndpoint,
        deviceId: 'dev-001',
      );
      expect(tpResult, hasLength(1));
    });

    test('listTrackingPoints handles bare array response', () async {
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response(
          jsonEncode([
            {
              'id': 'p-1',
              'latitude': 10.0,
              'longitude': 106.0,
              'eventTime': '2026-06-22T12:00:00.000Z',
            },
          ]),
          200,
        )),
      );
      final result = await client.listTrackingPoints(
        endpoint: _testEndpoint,
        deviceId: 'dev-001',
      );
      expect(result, hasLength(1));
      expect(result[0].id, 'p-1');
    });

    test('listTrackingPoints returns empty on unknown shape', () async {
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response(
          jsonEncode({'unexpected': 'shape'}),
          200,
        )),
      );
      final result = await client.listTrackingPoints(
        endpoint: _testEndpoint,
        deviceId: 'dev-001',
      );
      expect(result, isEmpty);
    });

    test('fetchVehicles handles wrapped response shapes', () async {
      // Test "vehicles" wrapper
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response(
          jsonEncode({
            'vehicles': [
              {'vehicleId': 'car-001', 'plateNumber': '51A-12345'},
            ],
          }),
          200,
        )),
      );
      final result = await client.fetchVehicles(endpoint: _testEndpoint);
      expect(result, hasLength(1));
      expect(result[0].vehicleId, 'car-001');
    });

    test('fetchVehicles returns empty on unknown shape', () async {
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response(
          jsonEncode({'status': 'ok'}),
          200,
        )),
      );
      final result = await client.fetchVehicles(endpoint: _testEndpoint);
      expect(result, isEmpty);
    });

    test('getVehicle parses nested "vehicle" key', () async {
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response(
          jsonEncode({
            'vehicle': {
              'vehicleId': 'car-001',
              'plateNumber': '51A-12345',
            },
          }),
          200,
        )),
      );
      final result = await client.getVehicle(
        endpoint: _testEndpoint,
        id: 'car-001',
      );
      expect(result.vehicleId, 'car-001');
      expect(result.plateNumber, '51A-12345');
    });

    test('getVehicle parses flat response as fallback', () async {
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response(
          jsonEncode({
            'vehicleId': 'car-002',
            'plateNumber': '59B-99999',
          }),
          200,
        )),
      );
      final result = await client.getVehicle(
        endpoint: _testEndpoint,
        id: 'car-002',
      );
      expect(result.vehicleId, 'car-002');
    });

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

    test('_vehicleServiceBase resolves endpoint with vehicle-service path',
        () async {
      final captured = <Uri>[];
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async {
          captured.add(req.url);
          return http.Response('[]', 200);
        }),
      );
      await client.fetchVehicles(
        endpoint: 'https://custom.host.com/vehicle-service',
      );
      expect(
        captured.single.toString(),
        contains('vehicle-service/client-api/v1/vehicles'),
      );
    });

    test('_vehicleServiceBase uses endpoint as-is if no vehicle-service segment',
        () async {
      final captured = <Uri>[];
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async {
          captured.add(req.url);
          return http.Response('[]', 200);
        }),
      );
      await client.fetchVehicles(
        endpoint: 'https://custom.host.com/api/v2',
      );
      expect(
        captured.single.toString(),
        contains('custom.host.com/api/v2/vehicles'),
      );
    });
  });
}
