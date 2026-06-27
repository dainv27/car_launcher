import 'dart:io';

import 'package:car_launcher/features/account/repositories/keycloak_auth_repository.dart';
import 'package:car_launcher/shared/data/location_service.dart';
import 'package:car_launcher/shared/data/vehicle_tracking_store_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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

  group('VehicleTrackingNotifier', () {
    test('starts disabled and records nothing', () async {
      final directory = Directory.systemTemp.createTempSync(
        'notifier_disabled_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: _NoOpSyncClient(),
        store: store,
        loadPersisted: false,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      expect(notifier.state.enabled, isFalse);
      notifier.recordLocation(
        const LocationInfo(displayName: 'Ignored', latitude: 10, longitude: 106),
      );
      expect(notifier.state.points, isEmpty);
      expect(notifier.state.pointCount, 0);
    });

    test('start enables tracking and records first point', () async {
      final directory = Directory.systemTemp.createTempSync(
        'notifier_start_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: _NoOpSyncClient(),
        store: store,
        loadPersisted: false,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      await notifier.start();
      expect(notifier.state.enabled, isTrue);

      notifier.recordLocation(
        const LocationInfo(displayName: 'Home', latitude: 10, longitude: 106),
        timestamp: DateTime.utc(2026, 6, 25, 12, 0),
      );
      expect(notifier.state.pointCount, 1);
      expect(notifier.state.lastPoint?.displayName, 'Home');
    });

    test('stop disables tracking', () async {
      final directory = Directory.systemTemp.createTempSync(
        'notifier_stop_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: _NoOpSyncClient(),
        store: store,
        loadPersisted: false,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      await notifier.start();
      expect(notifier.state.enabled, isTrue);

      await notifier.stop();
      expect(notifier.state.enabled, isFalse);

      notifier.recordLocation(
        const LocationInfo(displayName: 'Ignored', latitude: 11, longitude: 107),
      );
      expect(notifier.state.pointCount, 0);
    });

    test('clear resets points and distance', () async {
      final directory = Directory.systemTemp.createTempSync(
        'notifier_clear_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: _NoOpSyncClient(),
        store: store,
        loadPersisted: false,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      await notifier.start();
      notifier.recordLocation(
        const LocationInfo(displayName: 'A', latitude: 10, longitude: 106),
        timestamp: DateTime.utc(2026),
      );
      notifier.recordLocation(
        const LocationInfo(displayName: 'B', latitude: 10.001, longitude: 106),
        timestamp: DateTime.utc(2026, 1, 1, 0, 1),
      );
      expect(notifier.state.pointCount, 2);
      expect(notifier.state.distanceMeters, greaterThan(0));

      await notifier.clear();
      expect(notifier.state.points, isEmpty);
      expect(notifier.state.distanceMeters, 0);
    });

    test('ignores location updates below minimum distance', () async {
      final directory = Directory.systemTemp.createTempSync(
        'notifier_mindist_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: _NoOpSyncClient(),
        store: store,
        loadPersisted: false,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      await notifier.start();
      notifier.recordLocation(
        const LocationInfo(displayName: 'A', latitude: 10.0, longitude: 106.0),
        timestamp: DateTime.utc(2026, 1, 1, 12, 0),
      );
      // Move less than 5 meters (0.00001 degrees ≈ 1.1 meters)
      notifier.recordLocation(
        const LocationInfo(displayName: 'B', latitude: 10.00001, longitude: 106.0),
        timestamp: DateTime.utc(2026, 1, 1, 12, 1),
      );
      expect(notifier.state.pointCount, 1);
    });

    test('records location updates above minimum distance', () async {
      final directory = Directory.systemTemp.createTempSync(
        'notifier_abovemin_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: _NoOpSyncClient(),
        store: store,
        loadPersisted: false,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      await notifier.start();
      notifier.recordLocation(
        const LocationInfo(displayName: 'A', latitude: 10.0, longitude: 106.0),
        timestamp: DateTime.utc(2026, 1, 1, 12, 0),
      );
      // Move more than 5 meters (0.001 degrees ≈ 111 meters)
      notifier.recordLocation(
        const LocationInfo(displayName: 'B', latitude: 10.001, longitude: 106.0),
        timestamp: DateTime.utc(2026, 1, 1, 12, 1),
      );
      expect(notifier.state.pointCount, 2);
    });

    test('trims points beyond max capacity', () async {
      final directory = Directory.systemTemp.createTempSync(
        'notifier_maxpoints_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: _NoOpSyncClient(),
        store: store,
        loadPersisted: false,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      await notifier.start();
      // Record 1001 points (max is 1000)
      for (var i = 0; i < 1001; i++) {
        notifier.recordLocation(
          LocationInfo(
            displayName: 'Point $i',
            latitude: 10.0 + (i * 0.001),
            longitude: 106.0,
          ),
          timestamp: DateTime.utc(2026, 1, 1, 0, i),
        );
      }
      expect(notifier.state.pointCount, 1000);
    });

    test('calculates distance between points', () async {
      final directory = Directory.systemTemp.createTempSync(
        'notifier_distance_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: _NoOpSyncClient(),
        store: store,
        loadPersisted: false,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      await notifier.start();
      notifier.recordLocation(
        const LocationInfo(displayName: 'A', latitude: 10.0, longitude: 106.0),
        timestamp: DateTime.utc(2026, 1, 1, 12, 0),
      );
      notifier.recordLocation(
        const LocationInfo(displayName: 'B', latitude: 10.001, longitude: 106.0),
        timestamp: DateTime.utc(2026, 1, 1, 12, 1),
      );
      expect(notifier.state.distanceMeters, greaterThan(100));
      expect(notifier.state.hasRoute, isTrue);
    });

    test('setSyncEndpoint updates endpoint', () async {
      final directory = Directory.systemTemp.createTempSync(
        'notifier_endpoint_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: _NoOpSyncClient(),
        store: store,
        loadPersisted: false,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      await notifier.setSyncEndpoint('https://new-endpoint.example.com/api');
      expect(notifier.state.syncEndpoint, 'https://new-endpoint.example.com/api');
    });

    test('assignVehicle sets the active vehicle', () async {
      const channel = MethodChannel('com.carlauncher/native');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => true);

      final sync = _NoOpSyncClient();
      final directory = Directory.systemTemp.createTempSync(
        'notifier_assign_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: sync,
        store: store,
        loadPersisted: false,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      const vehicle = VehicleProfile(
        vehicleId: 'car-001',
        plateNumber: '51A-12345',
      );
      await notifier.assignVehicle(vehicle);
      expect(notifier.state.vehicle.vehicleId, 'car-001');
      expect(notifier.state.vehicle.plateNumber, '51A-12345');
    });

    test('loadVehicles fetches from sync client', () async {
      const channel = MethodChannel('com.carlauncher/native');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => true);

      final sync = _NoOpSyncClient()
        ..serverVehicles = const [
          VehicleProfile(vehicleId: 'car-001', plateNumber: '51A-12345'),
          VehicleProfile(vehicleId: 'car-002', plateNumber: '59B-99999'),
        ];
      final directory = Directory.systemTemp.createTempSync(
        'notifier_load_vehicles_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: sync,
        store: store,
        loadPersisted: false,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      await notifier.setSyncEndpoint('https://example.com');
      await notifier.loadVehicles();
      expect(notifier.state.vehicles, hasLength(2));
      expect(notifier.state.vehicles[0].vehicleId, 'car-001');
      expect(notifier.state.vehicles[1].vehicleId, 'car-002');
      expect(notifier.state.isLoadingVehicles, isFalse);
    });

    test('loadVehicles sets error on failure', () async {
      const channel = MethodChannel('com.carlauncher/native');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => true);

      final sync = _FailingSyncClient();
      final directory = Directory.systemTemp.createTempSync(
        'notifier_load_fail_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: sync,
        store: store,
        loadPersisted: false,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      await notifier.loadVehicles();
      expect(notifier.state.lastVehicleError, isNotNull);
      expect(notifier.state.isLoadingVehicles, isFalse);
    });

    test('formattedDistance shows correct units', () async {
      final directory = Directory.systemTemp.createTempSync(
        'notifier_format_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: _NoOpSyncClient(),
        store: store,
        loadPersisted: false,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      // Initial state has 0 distance
      expect(notifier.state.formattedDistance, '0 m');
    });

    test('saveVehicleProfile persists to store', () async {
      const channel = MethodChannel('com.carlauncher/native');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => true);

      final sync = _NoOpSyncClient();
      final directory = Directory.systemTemp.createTempSync(
        'notifier_save_profile_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: sync,
        store: store,
        loadPersisted: false,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      const vehicle = VehicleProfile(
        vehicleId: 'car-001',
        plateNumber: '51A-12345',
        name: 'Family car',
      );
      await notifier.saveVehicleProfile(vehicle);
      expect(notifier.state.vehicle.vehicleId, 'car-001');
      expect(notifier.state.vehicle.plateNumber, '51A-12345');

      // Verify persisted in store
      final snapshot = await store.load();
      expect(snapshot.vehicle.vehicleId, 'car-001');
    });
  });

  group('VehicleTrackingNotifier sync flow', () {
    test('syncNow requires assigned vehicle', () async {
      const channel = MethodChannel('com.carlauncher/native');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getConnectivityStatus') {
          return {'validated': true};
        }
        return true;
      });

      final sync = _RecordingSyncClient();
      final directory = Directory.systemTemp.createTempSync(
        'notifier_sync_no_vehicle_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: sync,
        store: store,
        loadPersisted: false,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      await notifier.start();
      notifier.recordLocation(
        const LocationInfo(displayName: 'A', latitude: 10, longitude: 106),
        timestamp: DateTime.utc(2026),
      );
      // No vehicle assigned, so sync should not happen
      await notifier.syncNow();
      expect(sync.calls, 0);
    });

    test('syncNow syncs pending points when vehicle is assigned', () async {
      const channel = MethodChannel('com.carlauncher/native');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getConnectivityStatus') {
          return {'validated': true};
        }
        return true;
      });

      final sync = _RecordingSyncClient();
      const vehicle = VehicleProfile(vehicleId: 'car-001');
      final directory = Directory.systemTemp.createTempSync(
        'notifier_sync_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: sync,
        store: store,
        loadPersisted: false,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      await notifier.setSyncEndpoint('https://tracking.example.test/points');
      await notifier.assignVehicle(vehicle);
      await notifier.start();
      notifier.recordLocation(
        const LocationInfo(displayName: 'A', latitude: 10, longitude: 106),
        timestamp: DateTime.utc(2026),
      );
      notifier.recordLocation(
        const LocationInfo(displayName: 'B', latitude: 10.001, longitude: 106),
        timestamp: DateTime.utc(2026, 1, 1, 0, 1),
      );
      await notifier.syncNow();
      for (var i = 0; i < 10 && notifier.state.pendingSyncCount > 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(sync.uploadedIds.toSet().length, 2);
      expect(notifier.state.pendingSyncCount, 0);
    });

    test('syncNow does not sync when offline', () async {
      const channel = MethodChannel('com.carlauncher/native');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getConnectivityStatus') {
          return {'validated': false}; // Not validated
        }
        return true;
      });

      final sync = _RecordingSyncClient();
      const vehicle = VehicleProfile(vehicleId: 'car-001');
      final directory = Directory.systemTemp.createTempSync(
        'notifier_sync_offline_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: sync,
        store: store,
        loadPersisted: false,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      await notifier.setSyncEndpoint('https://tracking.example.test/points');
      await notifier.assignVehicle(vehicle);
      await notifier.start();
      notifier.recordLocation(
        const LocationInfo(displayName: 'A', latitude: 10, longitude: 106),
        timestamp: DateTime.utc(2026),
      );
      await notifier.syncNow();
      // No sync should happen
      expect(sync.calls, 0);
      expect(notifier.state.pendingSyncCount, 1);
    });
  });
}

/// No-op sync client that does nothing (for unit tests not focused on sync).
class _NoOpSyncClient extends VehicleTrackingSyncClient {
  _NoOpSyncClient() : super(httpClient: _StubHttpClient());

  List<VehicleProfile> serverVehicles = const [];

  @override
  Future<void> sync({
    required String endpoint,
    required List<VehicleTrackPoint> points,
    VehicleProfile vehicle = const VehicleProfile(),
  }) async {}

  @override
  Future<List<VehicleProfile>> fetchVehicles({required String endpoint}) async {
    return serverVehicles;
  }

  @override
  Future<VehicleProfile> saveVehicle({
    required String endpoint,
    required VehicleProfile vehicle,
    Map<String, dynamic> deviceInfo = const {},
  }) async {
    return vehicle;
  }

  @override
  Future<void> ensureDeviceRegistered() async {}
}

/// Failing sync client that always throws.
class _FailingSyncClient extends VehicleTrackingSyncClient {
  _FailingSyncClient() : super(httpClient: _StubHttpClient());

  @override
  Future<List<VehicleProfile>> fetchVehicles({required String endpoint}) async {
    throw Exception('Network error');
  }
}

/// Recording sync client that tracks uploads.
class _RecordingSyncClient extends VehicleTrackingSyncClient {
  _RecordingSyncClient() : super(httpClient: _StubHttpClient());

  final uploadedIds = <String>[];
  final batchSizes = <int>[];
  List<VehicleProfile> serverVehicles = const [];
  int calls = 0;

  @override
  Future<void> sync({
    required String endpoint,
    required List<VehicleTrackPoint> points,
    VehicleProfile vehicle = const VehicleProfile(),
  }) async {
    calls++;
    batchSizes.add(points.length);
    uploadedIds.addAll(points.map((point) => point.id));
  }

  @override
  Future<List<VehicleProfile>> fetchVehicles({required String endpoint}) async {
    return serverVehicles;
  }

  @override
  Future<VehicleProfile> saveVehicle({
    required String endpoint,
    required VehicleProfile vehicle,
    Map<String, dynamic> deviceInfo = const {},
  }) async {
    final saved = vehicle.vehicleId.isEmpty
        ? vehicle.copyWith(vehicleId: 'server-car-001')
        : vehicle;
    final updated = [...serverVehicles];
    final index = updated.indexWhere(
      (item) => item.vehicleId == saved.vehicleId,
    );
    if (index >= 0) {
      updated[index] = saved;
    } else {
      updated.add(saved);
    }
    serverVehicles = updated;
    return saved;
  }
}

/// Stub HTTP client for subclasses that override all network methods.
class _StubHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(const []),
      200,
    );
  }
}
