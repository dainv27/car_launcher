import 'dart:convert';

import 'package:car_launcher/shared/data/location_service.dart';
import 'package:car_launcher/features/vehicle/domain/device.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _testEndpoint =
    'https://car-apis.202corp.com/vehicle-service/client-api/v1';

const _nativeChannel = MethodChannel('com.carlauncher/native');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeChannel, null);
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
        httpClient: MockClient((req) async => http.Response('error', 500)),
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

    test('sync succeeds on 2xx response', () async {
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response('{}', 200)),
      );
      final point = VehicleTrackPoint(
        id: 'p-1',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026),
      );
      // Should not throw
      await client.sync(
        endpoint: _testEndpoint,
        points: [point],
        vehicle: const VehicleProfile(vehicleId: 'car-001'),
      );
    });

    test('getLatestTrackingPoint throws on non-2xx/204 response', () async {
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response('error', 403)),
      );
      expect(
        client.getLatestTrackingPoint(
          endpoint: _testEndpoint,
          vehicleId: 'car-001',
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
          vehicleId: 'car-001',
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
        vehicleId: 'car-001',
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
        vehicleId: 'car-001',
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
        vehicleId: 'car-001',
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
        vehicleId: 'car-001',
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
        vehicleId: 'car-001',
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
        vehicleId: 'car-001',
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
      final client = VehicleTrackingSyncClient(
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

    test('ensureDeviceRegistered skips if no device info from native', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_nativeChannel, (call) async {
        if (call.method == 'getDeviceInfo') return null;
        return null;
      });

      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response('', 200)),
      );
      // Should not throw — just logs a warning and returns
      await client.ensureDeviceRegistered();
    });

    test('ensureDeviceRegistered skips if device info is empty', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_nativeChannel, (call) async {
        if (call.method == 'getDeviceInfo') return <dynamic, dynamic>{};
        return null;
      });

      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response('', 200)),
      );
      // Should not throw — just logs a warning and returns
      await client.ensureDeviceRegistered();
    });

    test('ensureDeviceRegistered skips if no stable device id derivable', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_nativeChannel, (call) async {
        if (call.method == 'getDeviceInfo') {
          // All identifying fields are empty → no device id can be derived
          return <dynamic, dynamic>{
            'androidId': '',
            'serial': '',
            'manufacturer': '',
            'model': '',
            'sdkInt': '',
          };
        }
        return null;
      });

      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async => http.Response('', 200)),
      );
      // Should not throw — just logs a warning and returns
      await client.ensureDeviceRegistered();
    });

    test('ensureDeviceRegistered registers device when not found', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_nativeChannel, (call) async {
        if (call.method == 'getDeviceInfo') {
          return <dynamic, dynamic>{
            'androidId': 'dev-001',
            'manufacturer': 'samsung',
            'model': 'SM-X133',
          };
        }
        return null;
      });

      var requestCount = 0;
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async {
          requestCount++;
          // GET returns 404 (device not found), POST returns 201
          if (req.method == 'GET') {
            return http.Response('', 404);
          }
          return http.Response(
            jsonEncode({'device': {'id': 'dev-001', 'name': 'samsung SM-X133'}}),
            201,
          );
        }),
      );
      await client.ensureDeviceRegistered();
      // Should have made a GET check and a POST create
      expect(requestCount, 2);
    });

    test('ensureDeviceRegistered skips if device already exists', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_nativeChannel, (call) async {
        if (call.method == 'getDeviceInfo') {
          return <dynamic, dynamic>{
            'androidId': 'dev-001',
            'manufacturer': 'samsung',
            'model': 'SM-X133',
          };
        }
        return null;
      });

      var requestCount = 0;
      final client = VehicleTrackingSyncClient(
        httpClient: MockClient((req) async {
          requestCount++;
          // GET returns 200 (device exists)
          return http.Response(
            jsonEncode({'device': {'id': 'dev-001'}}),
            200,
          );
        }),
      );
      await client.ensureDeviceRegistered();
      // Only the GET check, no POST
      expect(requestCount, 1);
    });

    test('createDevice returns existing device on 409', () async {
      final client = VehicleTrackingSyncClient(
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
