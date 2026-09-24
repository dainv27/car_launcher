import 'dart:convert';

import 'package:car_launcher/features/vehicle/data/vehicle_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _testEndpoint =
    'https://car-apis.202corp.com/vehicle-service/client-api/v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VehicleApiClient', () {
    test('fetchVehicles handles wrapped response shapes', () async {
      // Test "vehicles" wrapper
      final client = VehicleApiClient(
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
      expect(result[0].id, 'car-001');
    });

    test('fetchVehicles returns empty on unknown shape', () async {
      final client = VehicleApiClient(
        httpClient: MockClient((req) async => http.Response(
          jsonEncode({'status': 'ok'}),
          200,
        )),
      );
      final result = await client.fetchVehicles(endpoint: _testEndpoint);
      expect(result, isEmpty);
    });

    test('getVehicle parses nested "vehicle" key', () async {
      final client = VehicleApiClient(
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
      expect(result.id, 'car-001');
      expect(result.plateNumber, '51A-12345');
    });

    test('getVehicle parses flat response as fallback', () async {
      final client = VehicleApiClient(
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
      expect(result.id, 'car-002');
    });

    test('_vehicleServiceBase resolves endpoint with vehicle-service path',
        () async {
      final captured = <Uri>[];
      final client = VehicleApiClient(
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
      final client = VehicleApiClient(
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
