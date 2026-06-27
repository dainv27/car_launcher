import 'dart:io';

import 'package:car_launcher/shared/data/location_service.dart';
import 'package:car_launcher/shared/data/vehicle_tracking_store_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.carlauncher/native'),
      null,
    );
  });

  group('VehicleTrackingStoreService', () {
    late Directory directory;
    late VehicleTrackingStoreService store;

    setUp(() async {
      directory = Directory.systemTemp.createTempSync(
        'vehicle_tracking_store_test_',
      );
      store = VehicleTrackingStoreService(directory: directory);
    });

    tearDown(() async {
      await store.close();
      directory.deleteSync(recursive: true);
    });

    test('initial load returns default snapshot', () async {
      final snapshot = await store.load();
      expect(snapshot.enabled, isFalse);
      expect(snapshot.syncEndpoint, isEmpty);
      expect(snapshot.pending, isEmpty);
      expect(snapshot.synced, isEmpty);
      expect(snapshot.vehicle.vehicleId, isEmpty);
    });

    test('saveSettings persists enabled and syncEndpoint', () async {
      await store.saveSettings(
        enabled: true,
        syncEndpoint: 'https://api.example.com/vehicle-service',
      );
      final snapshot = await store.load();
      expect(snapshot.enabled, isTrue);
      expect(snapshot.syncEndpoint, 'https://api.example.com/vehicle-service');
    });

    test('saveVehicleProfile persists vehicle profile', () async {
      const vehicle = VehicleProfile(
        vehicleId: 'car-001',
        plateNumber: '51A-12345',
        name: 'Family car',
        make: 'Toyota',
        model: 'Vios',
        year: '2026',
      );
      await store.saveVehicleProfile(vehicle);
      final snapshot = await store.load();
      expect(snapshot.vehicle.vehicleId, 'car-001');
      expect(snapshot.vehicle.plateNumber, '51A-12345');
      expect(snapshot.vehicle.make, 'Toyota');
    });

    test('appendPending and readPending', () async {
      final point = VehicleTrackPoint(
        id: 'p-1',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026, 6, 25, 12, 0),
        displayName: 'Garage',
      );
      await store.appendPending(point);
      final pending = await store.readPending();
      expect(pending, hasLength(1));
      expect(pending[0].id, 'p-1');
      expect(pending[0].latitude, 10.0);
      expect(pending[0].longitude, 106.0);
      expect(pending[0].displayName, 'Garage');
    });

    test('appendPending ignores duplicate id', () async {
      final point = VehicleTrackPoint(
        id: 'dup-1',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026),
      );
      await store.appendPending(point);
      await store.appendPending(point); // same id, conflictAlgorithm.ignore
      final pending = await store.readPending();
      expect(pending, hasLength(1));
    });

    test('markSynced moves points from pending to synced', () async {
      final p1 = VehicleTrackPoint(
        id: 'p-1',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026, 6, 25, 12, 0),
        displayName: 'A',
      );
      final p2 = VehicleTrackPoint(
        id: 'p-2',
        latitude: 11.0,
        longitude: 107.0,
        timestamp: DateTime.utc(2026, 6, 25, 13, 0),
        displayName: 'B',
      );
      await store.appendPending(p1);
      await store.appendPending(p2);
      final syncedAt = DateTime.utc(2026, 6, 25, 14, 0);
      await store.markSynced({'p-1', 'p-2'}, syncedAt);
      final pending = await store.readPending();
      expect(pending, isEmpty);
      final snapshot = await store.load();
      expect(snapshot.synced, hasLength(2));
      expect(snapshot.synced[0].id, 'p-1');
      expect(snapshot.synced[1].id, 'p-2');
      expect(snapshot.synced.every((p) => p.synced), isTrue);
    });

    test('markSynced with empty set is a no-op', () async {
      await store.markSynced({}, DateTime.utc(2026));
      final pending = await store.readPending();
      expect(pending, isEmpty);
    });

    test('markSynced handles partial sync', () async {
      final p1 = VehicleTrackPoint(
        id: 'p-1',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026),
        displayName: 'A',
      );
      final p2 = VehicleTrackPoint(
        id: 'p-2',
        latitude: 11.0,
        longitude: 107.0,
        timestamp: DateTime.utc(2026, 1, 1, 1),
        displayName: 'B',
      );
      await store.appendPending(p1);
      await store.appendPending(p2);
      // Only sync p-1
      await store.markSynced({'p-1'}, DateTime.utc(2026, 1, 1, 2));
      final pending = await store.readPending();
      expect(pending, hasLength(1));
      expect(pending[0].id, 'p-2');
      final snapshot = await store.load();
      expect(snapshot.synced, hasLength(1));
      expect(snapshot.synced[0].id, 'p-1');
    });

    test('clear removes both pending and synced', () async {
      final point = VehicleTrackPoint(
        id: 'p-1',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026),
      );
      await store.appendPending(point);
      await store.markSynced({'p-1'}, DateTime.utc(2026, 1, 1));
      await store.clear();
      final snapshot = await store.load();
      expect(snapshot.pending, isEmpty);
      expect(snapshot.synced, isEmpty);
    });

    test('points getter merges synced and pending sorted by timestamp',
        () async {
      final p1 = VehicleTrackPoint(
        id: 'synced-1',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026, 1, 1),
      );
      await store.appendPending(p1);
      await store.markSynced({'synced-1'}, DateTime.utc(2026, 1, 2));
      final p2 = VehicleTrackPoint(
        id: 'pending-1',
        latitude: 11.0,
        longitude: 107.0,
        timestamp: DateTime.utc(2026, 1, 3),
      );
      await store.appendPending(p2);
      final snapshot = await store.load();
      expect(snapshot.points, hasLength(2));
      expect(snapshot.points[0].id, 'synced-1');
      expect(snapshot.points[1].id, 'pending-1');
    });
  });

  group('VehicleTrackPoint', () {
    test('fromLocation creates point with generated id', () {
      const location = LocationInfo(
        displayName: 'Home',
        latitude: 10.0,
        longitude: 106.0,
      );
      final point = VehicleTrackPoint.fromLocation(location);
      expect(point.id, isNotEmpty);
      expect(point.latitude, 10.0);
      expect(point.longitude, 106.0);
      expect(point.displayName, 'Home');
    });

    test('fromLocation with explicit timestamp', () {
      const location = LocationInfo(
        displayName: 'Work',
        latitude: 11.0,
        longitude: 107.0,
      );
      final ts = DateTime.utc(2026, 6, 25, 10, 30);
      final point = VehicleTrackPoint.fromLocation(location, timestamp: ts);
      expect(point.timestamp, ts);
    });

    test('markSynced returns a synced copy', () {
      final point = VehicleTrackPoint(
        id: 'p-1',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026),
      );
      expect(point.synced, isFalse);
      final syncedAt = DateTime.utc(2026, 1, 1);
      final synced = point.markSynced(syncedAt);
      expect(synced.synced, isTrue);
      expect(synced.syncedAt, syncedAt);
      expect(synced.id, 'p-1');
      expect(synced.latitude, 10.0);
    });

    test('distanceTo returns 0 for same point', () {
      final point = VehicleTrackPoint(
        id: 'p-1',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026),
      );
      expect(point.distanceTo(point), closeTo(0, 0.1));
    });

    test('distanceTo returns correct haversine distance', () {
      final a = VehicleTrackPoint(
        id: 'a',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026),
      );
      final b = VehicleTrackPoint(
        id: 'b',
        latitude: 10.001,
        longitude: 106.0,
        timestamp: DateTime.utc(2026, 1, 1),
      );
      // ~111 meters difference in latitude
      expect(a.distanceTo(b), greaterThan(100));
      expect(a.distanceTo(b), lessThan(120));
    });

    test('distanceTo is symmetric', () {
      final a = VehicleTrackPoint(
        id: 'a',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026),
      );
      final b = VehicleTrackPoint(
        id: 'b',
        latitude: 20.0,
        longitude: 116.0,
        timestamp: DateTime.utc(2026),
      );
      expect(a.distanceTo(b), closeTo(b.distanceTo(a), 0.001));
    });

    test('toJson / fromJson round-trip', () {
      final point = VehicleTrackPoint(
        id: 'p-1',
        latitude: 10.123456,
        longitude: 106.654321,
        timestamp: DateTime.utc(2026, 6, 25, 12, 30, 45),
        displayName: 'Test Location',
        syncedAt: DateTime.utc(2026, 6, 25, 13, 0),
      );
      final json = point.toJson();
      final restored = VehicleTrackPoint.fromJson(json);
      expect(restored.id, point.id);
      expect(restored.latitude, closeTo(point.latitude, 1e-9));
      expect(restored.longitude, closeTo(point.longitude, 1e-9));
      expect(restored.displayName, point.displayName);
      expect(restored.synced, isTrue);
    });

    test('toSyncJson omits syncedAt', () {
      final point = VehicleTrackPoint(
        id: 'p-1',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026),
        syncedAt: DateTime.utc(2026, 1, 1),
      );
      final json = point.toSyncJson();
      expect(json.containsKey('syncedAt'), isFalse);
      expect(json['id'], 'p-1');
    });

    test('toVehicleServiceJson produces correct shape', () {
      final point = VehicleTrackPoint(
        id: 'point-id',
        latitude: 10.5,
        longitude: 106.5,
        timestamp: DateTime.utc(2026, 6, 25, 14, 0),
        displayName: 'My Car',
      );
      final json = point.toVehicleServiceJson();
      expect(json['latitude'], 10.5);
      expect(json['longitude'], 106.5);
      expect(json['eventTime'], '2026-06-25T14:00:00.000Z');
      final metadata = json['metadata'] as Map<String, dynamic>;
      expect(metadata['clientPointId'], 'point-id');
      expect(metadata['displayName'], 'My Car');
    });

    test('toVehicleServiceJson omits displayName when empty', () {
      final point = VehicleTrackPoint(
        id: 'point-id',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026),
        displayName: '',
      );
      final json = point.toVehicleServiceJson();
      final metadata = json['metadata'] as Map<String, dynamic>;
      expect(metadata.containsKey('displayName'), isFalse);
    });
  });

  group('VehicleProfile', () {
    test('default has no data', () {
      const profile = VehicleProfile();
      expect(profile.hasData, isFalse);
      expect(profile.displayName, 'Not registered');
    });

    test('displayName prefers plateNumber', () {
      const profile = VehicleProfile(
        vehicleId: 'car-001',
        plateNumber: '51A-12345',
        name: 'My Car',
      );
      expect(profile.displayName, '51A-12345');
    });

    test('displayName falls back to name then vehicleId', () {
      const p1 = VehicleProfile(name: 'My Car');
      expect(p1.displayName, 'My Car');
      const p2 = VehicleProfile(vehicleId: 'car-001');
      expect(p2.displayName, 'car-001');
    });

    test('fromJson parses full shape', () {
      final profile = VehicleProfile.fromJson({
        'vehicleId': 'car-001',
        'plateNumber': '51A-12345',
        'name': 'Family car',
        'make': 'Toyota',
        'model': 'Vios',
        'year': '2026',
      });
      expect(profile.vehicleId, 'car-001');
      expect(profile.plateNumber, '51A-12345');
      expect(profile.make, 'Toyota');
      expect(profile.year, '2026');
    });

    test('fromJson maps "brand" to make and "id" to vehicleId', () {
      final profile = VehicleProfile.fromJson({
        'id': 'alt-id',
        'brand': 'Honda',
        'metadata': {'year': '2025'},
      });
      expect(profile.vehicleId, 'alt-id');
      expect(profile.make, 'Honda');
      expect(profile.year, '2025');
    });

    test('toJson includes id when vehicleId is set', () {
      const profile = VehicleProfile(vehicleId: 'car-001');
      final json = profile.toJson();
      expect(json['id'], 'car-001');
      expect(json['vehicleId'], 'car-001');
    });

    test('copyWith preserves unchanged fields', () {
      const profile = VehicleProfile(
        vehicleId: 'car-001',
        plateNumber: '51A-12345',
        make: 'Toyota',
      );
      final updated = profile.copyWith(plateNumber: '99Z-99999');
      expect(updated.vehicleId, 'car-001');
      expect(updated.plateNumber, '99Z-99999');
      expect(updated.make, 'Toyota');
    });

    test('toRegistrationJson uses "brand" key instead of "make"', () {
      const profile = VehicleProfile(make: 'Toyota', model: 'Vios');
      final json = profile.toRegistrationJson();
      expect(json.containsKey('brand'), isTrue);
      expect(json.containsKey('make'), isFalse);
      expect(json['brand'], 'Toyota');
    });
  });

  group('VehicleTrackingState', () {
    test('default state', () {
      const state = VehicleTrackingState();
      expect(state.enabled, isFalse);
      expect(state.points, isEmpty);
      expect(state.distanceMeters, 0);
      expect(state.isLoading, isFalse);
      expect(state.syncEndpoint, isEmpty);
      expect(state.isSyncing, isFalse);
      expect(state.pendingSyncCount, 0);
      expect(state.hasRoute, isFalse);
      expect(state.canSync, isFalse);
    });

    test('lastPoint returns null when empty', () {
      const state = VehicleTrackingState();
      expect(state.lastPoint, isNull);
    });

    test('lastPoint returns the last point', () {
      final p1 = VehicleTrackPoint(
        id: 'p-1',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026),
      );
      final p2 = VehicleTrackPoint(
        id: 'p-2',
        latitude: 11.0,
        longitude: 107.0,
        timestamp: DateTime.utc(2026, 1, 1),
      );
      final state = VehicleTrackingState(points: [p1, p2]);
      expect(state.lastPoint, p2);
    });

    test('pendingSyncCount counts unsynced points', () {
      final p1 = VehicleTrackPoint(
        id: 'p-1',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026),
      );
      final p2 = VehicleTrackPoint(
        id: 'p-2',
        latitude: 11.0,
        longitude: 107.0,
        timestamp: DateTime.utc(2026, 1, 1),
        syncedAt: DateTime.utc(2026, 1, 2),
      );
      final state = VehicleTrackingState(points: [p1, p2]);
      expect(state.pendingSyncCount, 1);
    });

    test('hasRoute is true when more than one point', () {
      final p1 = VehicleTrackPoint(
        id: 'p-1',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026),
      );
      final p2 = VehicleTrackPoint(
        id: 'p-2',
        latitude: 11.0,
        longitude: 107.0,
        timestamp: DateTime.utc(2026, 1, 1),
      );
      final state = VehicleTrackingState(points: [p1, p2]);
      expect(state.hasRoute, isTrue);
    });

    test('canSync requires vehicle and pending points', () {
      final p1 = VehicleTrackPoint(
        id: 'p-1',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026),
      );
      // No vehicle assigned
      expect(
        const VehicleTrackingState(points: []).canSync,
        isFalse,
      );
      // Vehicle assigned but no pending
      expect(
        VehicleTrackingState(
          vehicle: const VehicleProfile(vehicleId: 'car-001'),
          points: [p1],
        ).canSync,
        isTrue,
      );
      // Vehicle assigned but point is already synced
      final synced = p1.markSynced(DateTime.utc(2026, 1, 1));
      expect(
        VehicleTrackingState(
          vehicle: const VehicleProfile(vehicleId: 'car-001'),
          points: [synced],
        ).canSync,
        isFalse,
      );
    });

    test('formattedDistance shows meters for short distances', () {
      const state = VehicleTrackingState(distanceMeters: 500);
      expect(state.formattedDistance, '500 m');
    });

    test('formattedDistance shows km for long distances', () {
      const state = VehicleTrackingState(distanceMeters: 1500);
      expect(state.formattedDistance, '1.5 km');
    });

    test('copyWith preserves unchanged fields', () {
      const state = VehicleTrackingState(enabled: true, syncEndpoint: 'http://x');
      final updated = state.copyWith(enabled: false);
      expect(updated.enabled, isFalse);
      expect(updated.syncEndpoint, 'http://x');
    });

    test('copyWith can clear error with null', () {
      const state = VehicleTrackingState(lastSyncError: 'previous error');
      final updated = state.copyWith(lastSyncError: null);
      expect(updated.lastSyncError, isNull);
    });
  });

  group('VehicleTrackingSnapshot', () {
    test('points merges and sorts synced + pending by timestamp', () {
      final syncedPt = VehicleTrackPoint(
        id: 's-1',
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.utc(2026, 1, 1),
        syncedAt: DateTime.utc(2026, 1, 2),
      );
      final pendingPt = VehicleTrackPoint(
        id: 'p-1',
        latitude: 11.0,
        longitude: 107.0,
        timestamp: DateTime.utc(2026, 1, 3),
      );
      final snap = VehicleTrackingSnapshot(
        enabled: true,
        syncEndpoint: '',
        vehicle: const VehicleProfile(),
        pending: [pendingPt],
        synced: [syncedPt],
      );
      expect(snap.points, hasLength(2));
      expect(snap.points[0].id, 's-1');
      expect(snap.points[1].id, 'p-1');
    });
  });
}
