import 'package:car_launcher/shared/data/location_service.dart';
import 'package:car_launcher/features/vehicle/domain/device.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Vehicle', () {
    test('hasData is false for default', () {
      const vehicle = Vehicle();
      expect(vehicle.hasData, isFalse);
    });

    test('hasData is true when any field is set', () {
      expect(const Vehicle(id: 'x').hasData, isTrue);
      expect(const Vehicle(plateNumber: 'x').hasData, isTrue);
      expect(const Vehicle(name: 'x').hasData, isTrue);
      expect(const Vehicle(brand: 'x').hasData, isTrue);
      expect(const Vehicle(model: 'x').hasData, isTrue);
    });

    test('displayName priority: plateNumber > name > id', () {
      expect(
        const Vehicle(
          id: 'car-001',
          plateNumber: '51A-12345',
          name: 'Family car',
        ).displayName,
        '51A-12345',
      );
      expect(
        const Vehicle(id: 'car-001', name: 'Family car').displayName,
        'Family car',
      );
      expect(const Vehicle(id: 'car-001').displayName, 'car-001');
      expect(const Vehicle().displayName, 'Unknown vehicle');
    });

    test('year accessor from metadata', () {
      const vehicle = Vehicle(metadata: {'year': '2026'});
      expect(vehicle.year, '2026');
      const noYear = Vehicle(metadata: {'other': 'value'});
      expect(noYear.year, isEmpty);
      const noMetadata = Vehicle();
      expect(noMetadata.year, isEmpty);
    });

    test('fromJson handles multiple id shapes', () {
      // When both "id" and "vehicleId" present, prefer "id"
      final v1 = Vehicle.fromJson({
        'id': 'from-id',
        'vehicleId': 'from-vehicleId',
      });
      expect(v1.id, 'from-id');

      // Fall back to "vehicleId"
      final v2 = Vehicle.fromJson({'vehicleId': 'from-vehicleId'});
      expect(v2.id, 'from-vehicleId');

      // No id at all
      final v3 = Vehicle.fromJson({});
      expect(v3.id, isEmpty);
    });

    test('fromJson maps "make" field to brand as fallback', () {
      // "brand" takes priority over "make" (?? operator tries left first)
      final vehicle = Vehicle.fromJson({'brand': 'Honda', 'make': 'Toyota'});
      expect(vehicle.brand, 'Honda');

      // Only "make" present — falls back to "make"
      final withMake = Vehicle.fromJson({'make': 'Toyota'});
      expect(withMake.brand, 'Toyota');

      // Only "brand" present
      final withBrand = Vehicle.fromJson({'brand': 'Honda'});
      expect(withBrand.brand, 'Honda');
    });

    test('toJson includes vehicleId when id is set', () {
      const vehicle = Vehicle(id: 'car-001', plateNumber: '51A-12345');
      final json = vehicle.toJson();
      expect(json['id'], 'car-001');
      expect(json['vehicleId'], 'car-001');
      expect(json['plateNumber'], '51A-12345');
    });

    test('toJson omits empty id', () {
      const vehicle = Vehicle(plateNumber: '51A-12345');
      final json = vehicle.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('vehicleId'), isFalse);
    });

    test('toPatchJson includes mutable fields', () {
      const vehicle = Vehicle(
        plateNumber: '51A-12345',
        name: 'Family',
        brand: 'Toyota',
        model: 'Vios',
        metadata: {'year': '2026'},
      );
      final json = vehicle.toPatchJson();
      expect(json['plateNumber'], '51A-12345');
      expect(json['name'], 'Family');
      expect(json['brand'], 'Toyota');
      expect(json['model'], 'Vios');
      expect(json['metadata'], {'year': '2026'});
    });

    test('toProfile conversion preserves fields', () {
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
      expect(profile.name, 'Family car');
      expect(profile.make, 'Toyota');
      expect(profile.model, 'Vios');
      expect(profile.year, '2026');
    });

    test('fromProfile conversion', () {
      const profile = VehicleProfile(
        vehicleId: 'car-001',
        plateNumber: '51A-12345',
        name: 'Family car',
        make: 'Toyota',
        model: 'Vios',
        year: '2026',
      );
      final vehicle = Vehicle.fromProfile(profile);
      expect(vehicle.id, 'car-001');
      expect(vehicle.plateNumber, '51A-12345');
      expect(vehicle.brand, 'Toyota');
      expect(vehicle.year, '2026');
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
      final roundTrip = Vehicle.fromProfile(vehicle.toProfile());
      expect(roundTrip.id, vehicle.id);
      expect(roundTrip.plateNumber, vehicle.plateNumber);
      expect(roundTrip.name, vehicle.name);
      expect(roundTrip.brand, vehicle.brand);
      expect(roundTrip.model, vehicle.model);
      expect(roundTrip.year, vehicle.year);
    });

    test('equality based on id, plateNumber, name, brand, model', () {
      const a = Vehicle(
        id: 'car-001',
        plateNumber: '51A-12345',
        name: 'Family',
        brand: 'Toyota',
        model: 'Vios',
      );
      const b = Vehicle(
        id: 'car-001',
        plateNumber: '51A-12345',
        name: 'Family',
        brand: 'Toyota',
        model: 'Vios',
        metadata: {'year': '2026'}, // different, but not in equality
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith preserves unchanged fields', () {
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

    test('toString includes key fields', () {
      const vehicle = Vehicle(
        id: 'car-001',
        plateNumber: '51A-12345',
        name: 'Family car',
      );
      final str = vehicle.toString();
      expect(str, contains('car-001'));
      expect(str, contains('51A-12345'));
      expect(str, contains('Family car'));
    });
  });

  group('Device', () {
    test('hasData is false for default', () {
      const device = Device();
      expect(device.hasData, isFalse);
    });

    test('hasData is true when any key field is set', () {
      expect(const Device(id: 'x').hasData, isTrue);
      expect(const Device(vehicleId: 'x').hasData, isTrue);
      expect(const Device(name: 'x').hasData, isTrue);
      expect(const Device(serialNumber: 'x').hasData, isTrue);
    });

    test('displayName priority: name > serialNumber > id', () {
      expect(
        const Device(id: 'dev-1', serialNumber: 'SN-1', name: 'OBD').displayName,
        'OBD',
      );
      expect(
        const Device(id: 'dev-1', serialNumber: 'SN-1').displayName,
        'SN-1',
      );
      expect(const Device(id: 'dev-1').displayName, 'dev-1');
      expect(const Device().displayName, 'Unknown device');
    });

    test('fromJson parses all fields', () {
      final device = Device.fromJson({
        'id': 'dev-001',
        'vehicleId': 'car-001',
        'name': 'OBD dongle',
        'serialNumber': 'SN-001',
        'imei': 'IMEI-001',
        'phoneNumber': '+1234567890',
        'model': 'OBD-2',
        'firmwareVersion': '1.0',
        'metadata': {'sim': 'active'},
      });
      expect(device.id, 'dev-001');
      expect(device.vehicleId, 'car-001');
      expect(device.name, 'OBD dongle');
      expect(device.serialNumber, 'SN-001');
      expect(device.imei, 'IMEI-001');
      expect(device.phoneNumber, '+1234567890');
      expect(device.model, 'OBD-2');
      expect(device.firmwareVersion, '1.0');
      expect(device.metadata['sim'], 'active');
    });

    test('fromJson handles missing fields gracefully', () {
      final device = Device.fromJson({'id': 'dev-001'});
      expect(device.vehicleId, isEmpty);
      expect(device.name, isEmpty);
      expect(device.serialNumber, isEmpty);
      expect(device.imei, isEmpty);
      expect(device.phoneNumber, isEmpty);
      expect(device.model, isEmpty);
      expect(device.firmwareVersion, isEmpty);
      expect(device.metadata, isEmpty);
    });

    test('toJson omits empty fields', () {
      const device = Device(id: 'dev-001', name: 'OBD');
      final json = device.toJson();
      expect(json['id'], 'dev-001');
      expect(json['name'], 'OBD');
      expect(json.containsKey('vehicleId'), isFalse);
      expect(json.containsKey('serialNumber'), isFalse);
      expect(json.containsKey('imei'), isFalse);
      expect(json.containsKey('phoneNumber'), isFalse);
      expect(json.containsKey('model'), isFalse);
      expect(json.containsKey('firmwareVersion'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
    });

    test('toCreateJson matches toJson', () {
      const device = Device(
        id: 'dev-001',
        name: 'OBD',
        serialNumber: 'SN',
        metadata: {'key': 'val'},
      );
      expect(device.toCreateJson(), device.toJson());
    });

    test('copyWith preserves unchanged fields', () {
      const device = Device(id: 'dev-001', name: 'Old', imei: 'IMEI-1');
      final updated = device.copyWith(name: 'New');
      expect(updated.id, 'dev-001');
      expect(updated.name, 'New');
      expect(updated.imei, 'IMEI-1');
    });

    test('equality based on id, vehicleId, name, serialNumber', () {
      const a = Device(
        id: 'dev-1',
        vehicleId: 'car-1',
        name: 'OBD',
        serialNumber: 'SN-1',
      );
      const b = Device(
        id: 'dev-1',
        vehicleId: 'car-1',
        name: 'OBD',
        serialNumber: 'SN-1',
        imei: 'IMEI', // different, but not in equality
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes key fields', () {
      const device = Device(id: 'dev-1', vehicleId: 'car-1', name: 'OBD');
      final str = device.toString();
      expect(str, contains('dev-1'));
      expect(str, contains('car-1'));
      expect(str, contains('OBD'));
    });
  });
}
