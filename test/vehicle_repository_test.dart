import 'dart:convert';

import 'package:car_launcher/shared/data/location_service.dart';
import 'package:car_launcher/features/vehicle/data/vehicle_repository.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _testEndpoint =
    'https://car-apis.202corp.com/vehicle-service/client-api/v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VehicleRepository', () {
    test('listVehicles maps VehicleProfile list to Vehicle list', () async {
      final responseBody = jsonEncode([
        {
          'id': 'car-001',
          'vehicleId': 'car-001',
          'plateNumber': '51A-12345',
          'name': 'Family car',
          'brand': 'Toyota',
          'model': 'Vios',
          'metadata': {'year': '2026'},
        },
      ]);
      final client = VehicleTrackingSyncClient(
        httpClient: _mockClient(body: responseBody),
      );
      final repo = VehicleRepository(
        syncClient: client,
        syncEndpoint: _testEndpoint,
      );
      final vehicles = await repo.listVehicles();
      expect(vehicles, hasLength(1));
      expect(vehicles[0].id, 'car-001');
      expect(vehicles[0].plateNumber, '51A-12345');
      expect(vehicles[0].brand, 'Toyota');
      expect(vehicles[0].year, '2026');
    });

    test('listVehicles returns empty list on empty response', () async {
      final client = VehicleTrackingSyncClient(
        httpClient: _mockClient(body: jsonEncode([])),
      );
      final repo = VehicleRepository(
        syncClient: client,
        syncEndpoint: _testEndpoint,
      );
      final vehicles = await repo.listVehicles();
      expect(vehicles, isEmpty);
    });

    test('getVehicle returns a single vehicle by id', () async {
      final responseBody = jsonEncode({
        'id': 'car-002',
        'vehicleId': 'car-002',
        'plateNumber': '59B-99999',
        'name': 'Work car',
        'brand': 'Honda',
        'model': 'Civic',
      });
      final client = VehicleTrackingSyncClient(
        httpClient: _mockClient(body: responseBody),
      );
      final repo = VehicleRepository(
        syncClient: client,
        syncEndpoint: _testEndpoint,
      );
      final vehicle = await repo.getVehicle('car-002');
      expect(vehicle.id, 'car-002');
      expect(vehicle.plateNumber, '59B-99999');
      expect(vehicle.brand, 'Honda');
    });

    test('createVehicle maps result back to Vehicle', () async {
      final responseBody = jsonEncode({
        'vehicle': {
          'id': 'car-003',
          'vehicleId': 'car-003',
          'plateNumber': '30C-11111',
          'name': 'New car',
          'brand': 'Ford',
          'model': 'Ranger',
        },
      });
      final client = VehicleTrackingSyncClient(
        httpClient: _mockClient(body: responseBody),
      );
      final repo = VehicleRepository(
        syncClient: client,
        syncEndpoint: _testEndpoint,
      );
      final created = await repo.createVehicle(
        const Vehicle(
          plateNumber: '30C-11111',
          name: 'New car',
          brand: 'Ford',
          model: 'Ranger',
        ),
      );
      expect(created.id, 'car-003');
      expect(created.plateNumber, '30C-11111');
    });

    test('updateVehicle sends patch and returns updated vehicle', () async {
      final responseBody = jsonEncode({
        'id': 'car-001',
        'vehicleId': 'car-001',
        'plateNumber': '51A-UPDATED',
        'name': 'Family car',
        'brand': 'Toyota',
        'model': 'Vios',
      });
      final client = VehicleTrackingSyncClient(
        httpClient: _mockClient(body: responseBody),
      );
      final repo = VehicleRepository(
        syncClient: client,
        syncEndpoint: _testEndpoint,
      );
      final updated = await repo.updateVehicle(
        'car-001',
        const Vehicle(
          id: 'car-001',
          plateNumber: '51A-UPDATED',
          name: 'Family car',
          brand: 'Toyota',
          model: 'Vios',
        ),
      );
      expect(updated.plateNumber, '51A-UPDATED');
    });
  });

  group('Vehicle domain model', () {
    test('fromJson parses API response shape', () {
      final vehicle = Vehicle.fromJson({
        'id': 'car-001',
        'vehicleId': 'car-001',
        'plateNumber': '51A-12345',
        'name': 'Family car',
        'brand': 'Toyota',
        'model': 'Vios',
        'metadata': {'year': '2026'},
      });
      expect(vehicle.id, 'car-001');
      expect(vehicle.plateNumber, '51A-12345');
      expect(vehicle.brand, 'Toyota');
      expect(vehicle.year, '2026');
    });

    test('fromJson handles missing metadata', () {
      final vehicle = Vehicle.fromJson({
        'id': 'car-001',
        'plateNumber': '51A-12345',
      });
      expect(vehicle.id, 'car-001');
      expect(vehicle.metadata, isEmpty);
      expect(vehicle.year, isEmpty);
    });

    test('fromJson maps "make" to brand', () {
      final vehicle = Vehicle.fromJson({'make': 'Toyota'});
      expect(vehicle.brand, 'Toyota');
    });

    test('toProfile / fromProfile round-trip', () {
      const vehicle = Vehicle(
        id: 'car-001',
        plateNumber: '51A-12345',
        name: 'Family car',
        brand: 'Toyota',
        model: 'Vios',
        metadata: {'year': '2026'},
      );
      final profile = vehicle.toProfile();
      expect(profile.vehicleId, 'car-001');
      expect(profile.plateNumber, '51A-12345');
      expect(profile.make, 'Toyota');
      expect(profile.year, '2026');

      final roundTrip = Vehicle.fromProfile(profile);
      expect(roundTrip.id, vehicle.id);
      expect(roundTrip.plateNumber, vehicle.plateNumber);
      expect(roundTrip.brand, vehicle.brand);
      expect(roundTrip.year, vehicle.year);
    });

    test('displayName returns plateNumber first', () {
      const vehicle = Vehicle(plateNumber: '51A-12345', name: 'Family car');
      expect(vehicle.displayName, '51A-12345');
    });

    test('displayName falls back to name then id', () {
      const v1 = Vehicle(name: 'My car');
      expect(v1.displayName, 'My car');
      const v2 = Vehicle(id: 'car-001');
      expect(v2.displayName, 'car-001');
      const v3 = Vehicle();
      expect(v3.displayName, 'Unknown vehicle');
    });

    test('copyWith works correctly', () {
      const vehicle = Vehicle(
        id: 'car-001',
        plateNumber: '51A-12345',
        brand: 'Toyota',
      );
      final updated = vehicle.copyWith(plateNumber: '99Z-99999');
      expect(updated.id, 'car-001');
      expect(updated.plateNumber, '99Z-99999');
      expect(updated.brand, 'Toyota');
    });

    test('toJson includes metadata when present', () {
      const vehicle = Vehicle(id: 'car-001', metadata: {'year': '2026'});
      final json = vehicle.toJson();
      expect(json['metadata'], isNotNull);
      expect((json['metadata'] as Map)['year'], '2026');
    });

    test('toPatchJson includes all mutable fields', () {
      const vehicle = Vehicle(
        plateNumber: '51A-12345',
        name: 'Family car',
        brand: 'Toyota',
        model: 'Vios',
        metadata: {'year': '2026'},
      );
      final json = vehicle.toPatchJson();
      expect(json.containsKey('plateNumber'), isTrue);
      expect(json.containsKey('name'), isTrue);
      expect(json.containsKey('brand'), isTrue);
      expect(json.containsKey('model'), isTrue);
      expect(json.containsKey('metadata'), isTrue);
    });
  });
}

/// Create a mock HTTP client that always returns the given body with 200.
http.Client _mockClient({required String body}) {
  return MockClient((request) async {
    return http.Response(body, 200);
  });
}
