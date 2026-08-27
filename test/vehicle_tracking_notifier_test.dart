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

  /// Waits until [notifier]'s async load/refresh settles, bounded so a stuck
  /// future fails the test instead of hanging it.
  Future<void> pumpUntilNotLoading(VehicleTrackingNotifier notifier) async {
    for (var i = 0; i < 50 && notifier.state.isLoading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  group('VehicleTrackingNotifier', () {
    test('starts disabled and shows no points', () async {
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
      expect(notifier.state.points, isEmpty);
      expect(notifier.state.pointCount, 0);
    });

    test('start enables tracking', () async {
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
    });

    test(
      'reflects points the native service already wrote to the shared store',
      () async {
        // Native is the only writer in production; this simulates that by
        // seeding the shared SQLite store directly, the way
        // VehicleTrackingService.appendPoint() does on the Kotlin side.
        final directory = Directory.systemTemp.createTempSync(
          'notifier_store_points_test_',
        );
        final store = VehicleTrackingStoreService(directory: directory);
        await store.appendPending(
          VehicleTrackPoint(
            id: 'p1',
            latitude: 10.0,
            longitude: 106.0,
            timestamp: DateTime.utc(2026, 1, 1, 12, 0),
          ),
        );
        await store.appendPending(
          VehicleTrackPoint(
            id: 'p2',
            latitude: 10.001,
            longitude: 106.0,
            timestamp: DateTime.utc(2026, 1, 1, 12, 1),
          ),
        );

        final auth = KeycloakAuthRepository();
        final notifier = VehicleTrackingNotifier(
          auth,
          syncClient: _NoOpSyncClient(),
          store: store,
        );
        addTearDown(() async {
          notifier.dispose();
          await store.close();
          directory.deleteSync(recursive: true);
        });

        await pumpUntilNotLoading(notifier);
        expect(notifier.state.pointCount, 2);
        expect(notifier.state.distanceMeters, greaterThan(100));
        expect(notifier.state.hasRoute, isTrue);
      },
    );

    test('clear resets points and distance', () async {
      final directory = Directory.systemTemp.createTempSync(
        'notifier_clear_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      await store.appendPending(
        VehicleTrackPoint(
          id: 'p1',
          latitude: 10.0,
          longitude: 106.0,
          timestamp: DateTime.utc(2026, 1, 1, 12, 0),
        ),
      );
      final auth = KeycloakAuthRepository();
      final notifier = VehicleTrackingNotifier(
        auth,
        syncClient: _NoOpSyncClient(),
        store: store,
      );
      addTearDown(() async {
        notifier.dispose();
        await store.close();
        directory.deleteSync(recursive: true);
      });

      await pumpUntilNotLoading(notifier);
      expect(notifier.state.pointCount, 1);

      await notifier.clear();
      expect(notifier.state.points, isEmpty);
      expect(notifier.state.distanceMeters, 0);
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

  // Flutter never captures tracking points or uploads them itself — the
  // native background service owns both (offline-first: durable local write
  // regardless of connectivity, opportunistic upload). These tests cover
  // Dart's only remaining role: nudging native and reading back its result.
  group('VehicleTrackingNotifier syncNow', () {
    test('invokes the native sync trigger and refreshes from the store', () async {
      final invokedMethods = <String>[];
      const channel = MethodChannel('com.carlauncher/native');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        invokedMethods.add(call.method);
        return true;
      });

      final sync = _RecordingSyncClient();
      final directory = Directory.systemTemp.createTempSync(
        'notifier_syncnow_test_',
      );
      final store = VehicleTrackingStoreService(directory: directory);
      // Simulate native having already synced this point before Flutter's
      // nudge — the read-only refresh should surface it.
      await store.appendPending(
        VehicleTrackPoint(
          id: 'p1',
          latitude: 10,
          longitude: 106,
          timestamp: DateTime.utc(2026),
        ),
      );
      await store.markSynced({'p1'}, DateTime.utc(2026, 1, 1, 0, 0, 5));

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

      await notifier.syncNow();

      expect(invokedMethods, contains('syncVehicleTrackingNow'));
      expect(notifier.state.isSyncing, isFalse);
      expect(notifier.state.pointCount, 1);
      expect(notifier.state.pendingSyncCount, 0);
      // The whole point of this change: Dart must never call the HTTP sync
      // client itself, or it would race and double-upload against native.
      expect(sync.calls, 0);
    });

    test('tolerates the native channel being unavailable', () async {
      // No mock handler registered on 'com.carlauncher/native' — simulates
      // tests/non-Android platforms, matching how other native calls in
      // this codebase degrade.
      final sync = _RecordingSyncClient();
      final directory = Directory.systemTemp.createTempSync(
        'notifier_syncnow_no_native_test_',
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

      await notifier.syncNow();

      expect(notifier.state.isSyncing, isFalse);
      expect(sync.calls, 0);
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

/// Recording sync client that tracks uploads — used to prove Dart never
/// calls it from [VehicleTrackingNotifier.syncNow] anymore.
class _RecordingSyncClient extends VehicleTrackingSyncClient {
  _RecordingSyncClient() : super(httpClient: _StubHttpClient());

  final uploadedIds = <String>[];
  int calls = 0;

  @override
  Future<void> sync({
    required String endpoint,
    required List<VehicleTrackPoint> points,
    VehicleProfile vehicle = const VehicleProfile(),
  }) async {
    calls++;
    uploadedIds.addAll(points.map((point) => point.id));
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
