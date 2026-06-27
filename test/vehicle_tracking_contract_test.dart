import 'dart:io';

import 'package:car_launcher/features/account/repositories/keycloak_auth_repository.dart';
import 'package:car_launcher/shared/data/location_service.dart';
import 'package:car_launcher/shared/data/vehicle_tracking_store_service.dart';
import 'package:car_launcher/features/vehicle/domain/device.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
    // Mock flutter_secure_storage for KeycloakAuthRepository
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            if (call.method == 'read') return null;
            if (call.method == 'write') return null;
            if (call.method == 'delete') return null;
            if (call.method == 'containsKey') return false;
            return null;
          },
        );
    // Mock openidconnect secure storage
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.concerti.io/openidconnect_secure_storage'),
          (call) async {
            if (call.method == 'initialize') return null;
            if (call.method == 'read') return null;
            if (call.method == 'write') return null;
            if (call.method == 'delete') return null;
            if (call.method == 'containsKey') return false;
            return null;
          },
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.carlauncher/native'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.concerti.io/openidconnect_secure_storage'),
          null,
        );
  });

  test('vehicle tracking records movement only while enabled', () async {
    const channel = MethodChannel('com.carlauncher/native');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => true);

    final directory = Directory.systemTemp.createTempSync(
      'vehicle_tracking_test_',
    );
    final store = VehicleTrackingStoreService(directory: directory);
    final auth = KeycloakAuthRepository();
    final syncClient = VehicleTrackingSyncClient(
      httpClient: MockClient((req) async => http.Response('{}', 200)),
    );
    final notifier = VehicleTrackingNotifier(
      auth,
      syncClient: syncClient,
      store: store,
      loadPersisted: false,
    );
    addTearDown(() async {
      notifier.dispose();
      await store.close();
      directory.deleteSync(recursive: true);
    });

    notifier.recordLocation(
      const LocationInfo(displayName: 'Ignored', latitude: 10, longitude: 106),
    );
    expect(notifier.state.points, isEmpty);

    await notifier.start();
    notifier.recordLocation(
      const LocationInfo(displayName: 'Start', latitude: 10, longitude: 106),
      timestamp: DateTime.utc(2026),
    );
    notifier.recordLocation(
      const LocationInfo(displayName: 'End', latitude: 10.001, longitude: 106),
      timestamp: DateTime.utc(2026, 1, 1, 0, 1),
    );

    expect(notifier.state.enabled, isTrue);
    expect(notifier.state.pointCount, 2);
    expect(notifier.state.pendingSyncCount, 2);
    expect(notifier.state.distanceMeters, greaterThan(100));
    expect(notifier.state.lastPoint?.displayName, 'End');

    // Disable tracking — stop() calls auth.accessToken() which may fail in
    // tests without a real Keycloak server, so we just verify the state change.
    try {
      await notifier.stop();
    } catch (_) {
      // Swallow auth-related errors in test environment.
    }
    expect(notifier.state.enabled, isFalse);
    notifier.recordLocation(
      const LocationInfo(
        displayName: 'Ignored 2',
        latitude: 10.002,
        longitude: 106,
      ),
    );
    expect(notifier.state.pointCount, 2);

    await notifier.clear();
    expect(notifier.state.points, isEmpty);
    expect(notifier.state.distanceMeters, 0);
  });

  test(
    'vehicle tracking sync marks points once after successful upload',
    () async {
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
        'vehicle_tracking_sync_test_',
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
      final snapshot = await store.load();
      expect(snapshot.pending, isEmpty);
      expect(snapshot.synced.length, 2);
      expect(snapshot.synced.every((point) => point.synced), isTrue);

      await notifier.syncNow();
      expect(sync.calls, 1);
    },
  );

  test('vehicle tracking sync uploads pending points in batches', () async {
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
      'vehicle_tracking_batch_test_',
    );
    final store = VehicleTrackingStoreService(directory: directory);
    final auth = KeycloakAuthRepository();
    final notifier = VehicleTrackingNotifier(
      auth,
      syncClient: sync,
      store: store,
      syncBatchSize: 2,
      loadPersisted: false,
    );
    addTearDown(() async {
      notifier.dispose();
      await store.close();
      directory.deleteSync(recursive: true);
    });

    await notifier.assignVehicle(vehicle);
    await notifier.start();
    for (var i = 0; i < 5; i++) {
      notifier.recordLocation(
        LocationInfo(
          displayName: 'Point $i',
          latitude: 10 + (i * 0.001),
          longitude: 106,
        ),
        timestamp: DateTime.utc(2026, 1, 1, 0, i),
      );
    }
    await notifier.setSyncEndpoint('https://tracking.example.test/points');
    for (var i = 0; i < 30 && sync.batchSizes.length < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    for (var i = 0; i < 20 && notifier.state.pendingSyncCount > 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(sync.batchSizes, [2, 2, 1]);
    expect(sync.uploadedIds.toSet().length, 5);
    expect(notifier.state.pendingSyncCount, 0);
  });

  test(
    'vehicle tracking sync client sends tracking point body',
    () async {
      final client = _CapturingHttpClient();
      final sync = VehicleTrackingSyncClient(
        httpClient: client,
      );

      await sync.sync(
        endpoint: 'https://dev-car-apis.202corp.com/vehicle-service',
        vehicle: const VehicleProfile(
          vehicleId: 'car-001',
          plateNumber: '51A-12345',
          name: 'Family car',
        ),
        points: [
          VehicleTrackPoint.fromLocation(
            const LocationInfo(
              displayName: 'Garage',
              latitude: 10,
              longitude: 106,
            ),
            timestamp: DateTime.utc(2026),
          ),
        ],
      );

      expect(client.lastHeaders?['Content-Type'], 'application/json');
      expect(
        client.lastUrl.toString(),
        'https://dev-car-apis.202corp.com/vehicle-service/client-api/v1/vehicles/car-001/tracking-points',
      );
      expect(client.lastBody, contains('eventTime'));
      expect(client.lastBody, contains('metadata'));
      expect(client.lastBody, contains('clientPointId'));
      expect(client.lastBody, contains('Garage'));
    },
  );

  test('vehicle profile is saved and exposed to tracking state', () async {
    const channel = MethodChannel('com.carlauncher/native');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => true);

    final sync = _RecordingSyncClient();
    final directory = Directory.systemTemp.createTempSync(
      'vehicle_tracking_vehicle_test_',
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
      make: 'Toyota',
      model: 'Vios',
      year: '2026',
    );
    await notifier.setSyncEndpoint('https://tracking.example.test/points');
    await notifier.saveVehicleProfile(vehicle);

    expect(notifier.state.vehicle.plateNumber, '51A-12345');
    final snapshot = await store.load();
    expect(snapshot.vehicle.model, 'Vios');
  });

  test(
    'vehicle management loads vehicles and assigns one to the device',
    () async {
      const channel = MethodChannel('com.carlauncher/native');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => true);

      final sync = _RecordingSyncClient()
        ..serverVehicles = const [
          VehicleProfile(vehicleId: 'car-001', plateNumber: '51A-12345'),
          VehicleProfile(vehicleId: 'car-002', plateNumber: '51B-99999'),
        ];
      final directory = Directory.systemTemp.createTempSync(
        'vehicle_tracking_vehicle_list_test_',
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
      await notifier.loadVehicles();
      await notifier.assignVehicle(sync.serverVehicles.last);

      expect(notifier.state.vehicles.length, 2);
      expect(notifier.state.vehicle.vehicleId, 'car-002');
    },
  );

  test('vehicle api client uses vehicle service paths', () async {
    final client = _CapturingHttpClient(
      responseBody: '{"vehicles":[{"id":"car-001","plateNumber":"51A-12345"}]}',
    );
    final sync = VehicleTrackingSyncClient(
      httpClient: client,
    );

    final vehicles = await sync.fetchVehicles(
      endpoint: 'https://car-apis.202corp.com/vehicle-service/client-api/v1',
    );

    expect(vehicles.single.vehicleId, 'car-001');
    expect(
      client.lastUrl.toString(),
      'https://car-apis.202corp.com/vehicle-service/client-api/v1/vehicles?page=0&size=10',
    );
  });

  test(
    'vehicle save omits vehicleId and id, uses registration format',
    () async {
      final client = _CapturingHttpClient(
        responses: [
          _FakeHttpResponse(
            201,
            '{"id":"server-car-001","plateNumber":"51A-12345"}',
          ),
        ],
      );
      final sync = VehicleTrackingSyncClient(
        httpClient: client,
      );

      final saved = await sync.saveVehicle(
        endpoint: 'https://car-apis.202corp.com/vehicle-service/client-api/v1',
        vehicle: const VehicleProfile(
          plateNumber: '51A-12345',
          name: 'Family car',
        ),
      );

      final vehicleBody = client.requestBodies[0];
      expect(saved.vehicleId, 'server-car-001');
      expect(
        client.requestUrls[0].toString(),
        'https://car-apis.202corp.com/vehicle-service/client-api/v1/vehicles',
      );
      expect(vehicleBody, contains('"plateNumber":"51A-12345"'));
      expect(vehicleBody, contains('"name":"Family car"'));
      expect(vehicleBody, isNot(contains('"vehicleId"')));
      expect(vehicleBody, isNot(contains('"id"')));
    },
  );

  test(
    'ensureDeviceRegistered registers device with correct payload',
    () async {
      const nativeChannel = MethodChannel('com.carlauncher/native');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(nativeChannel, (call) async {
        if (call.method == 'getDeviceInfo') {
          return <dynamic, dynamic>{
            'androidId': 'android-abc',
            'manufacturer': 'samsung',
            'model': 'SM-X133',
            'serial': 'R8YY91N3TAF',
            'sdkInt': 36,
          };
        }
        return null;
      });

      final client = _CapturingHttpClient(
        responses: [
          const _FakeHttpResponse(404, ''), // GET device → not found
          _FakeHttpResponse(
            201,
            '{"device":{"id":"android-abc","name":"samsung SM-X133"}}',
          ), // POST device → created
        ],
      );
      final sync = VehicleTrackingSyncClient(
        httpClient: client,
      );

      await sync.ensureDeviceRegistered();

      // GET check + POST create
      expect(client.requestUrls.length, 2);
      expect(
        client.requestUrls[0].toString(),
        'https://dev-car-apis.202corp.com/vehicle-service/client-api/v1/devices/android-abc',
      );
      expect(
        client.requestUrls[1].toString(),
        'https://dev-car-apis.202corp.com/vehicle-service/client-api/v1/devices',
      );
      final deviceBody = client.requestBodies[1];
      expect(deviceBody, contains('"id":"android-abc"'));
      expect(deviceBody, contains('"serialNumber":"R8YY91N3TAF"'));
      expect(deviceBody, contains('"model":"SM-X133"'));
      expect(deviceBody, contains('"name":"samsung SM-X133"'));
    },
  );

  test(
    'vehicle tracking is surfaced on dashboard map, top bar, settings, and native service',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final mainActivity = File(
        'android/app/src/main/kotlin/com/carlauncher/car_launcher/MainActivity.kt',
      ).readAsStringSync();
      final bootReceiver = File(
        'android/app/src/main/kotlin/com/carlauncher/car_launcher/BootReceiver.kt',
      ).readAsStringSync();
      final nativeService = File(
        'android/app/src/main/kotlin/com/carlauncher/car_launcher/VehicleTrackingService.kt',
      ).readAsStringSync();
      final mapPage = File(
        'lib/features/dashboard/all_dashboard/map.dart',
      ).readAsStringSync();
      final mapWithMedia = File(
        'lib/features/dashboard/all_dashboard/map_with_media.dart',
      ).readAsStringSync();
      final mapWithYoutube = File(
        'lib/features/dashboard/all_dashboard/map_with_youtube.dart',
      ).readAsStringSync();
      final settings = File(
        'lib/features/settings/presentation/settings_page.dart',
      ).readAsStringSync();
      final topBar = File(
        'lib/features/dashboard/presentation/widgets/top_app_bar.dart',
      ).readAsStringSync();
      final widget = File(
        'lib/features/dashboard/presentation/widgets/vehicle_tracking_card.dart',
      ).readAsStringSync();
      final service = File(
        'lib/shared/data/location_service.dart',
      ).readAsStringSync();

      expect(service, contains('vehicleTrackingProvider'));
      expect(service, contains('pendingSyncCount'));
      expect(service, contains('syncedAt'));
      expect(service, contains('VehicleTrackingSyncClient'));
      expect(service, contains('VehicleTrackingStoreService'));
      expect(mapPage, isNot(contains('VehicleTrackingBadge')));
      expect(mapWithMedia, isNot(contains('VehicleTrackingBadge')));
      expect(mapWithYoutube, isNot(contains('VehicleTrackingBadge')));
      expect(topBar, contains("Key('top-bar-tracking-dot')"));
      expect(settings, contains("Key('settings-vehicle-tracking-card')"));
      expect(settings, contains('VehicleTrackingSettingsCard'));
      expect(widget, isNot(contains("Key('vehicle-tracking-sync-endpoint')")));
      expect(widget, isNot(contains('Vehicle API')));
      expect(widget, isNot(contains('Vehicle service API')));
      expect(widget, contains("Key('vehicle-profile-register')"));
      expect(widget, contains("Key('vehicle-profile-refresh')"));
      expect(widget, contains("Key('vehicle-profile-plate-input')"));
      expect(widget, isNot(contains("Key('vehicle-profile-id-input')")));
      expect(widget, contains("Key('vehicle-tracking-sync-now')"));
      expect(widget, contains("Key('vehicle-tracking-clear')"));
      expect(
        manifest,
        contains('android.permission.FOREGROUND_SERVICE_LOCATION'),
      );
      expect(manifest, contains('android:foregroundServiceType="location"'));
      expect(nativeService, contains('startForeground'));
      expect(nativeService, contains('requestLocationUpdates'));
      expect(nativeService, contains('SQLiteOpenHelper'));
      expect(nativeService, contains('HttpURLConnection'));
      expect(nativeService, contains('KEY_VEHICLE_PROFILE'));
      expect(nativeService, contains('tracking-points'));
      expect(nativeService, contains('SYNC_BATCH_SIZE'));
      expect(nativeService, contains('pending_points'));
      expect(nativeService, contains('synced_points'));
      expect(mainActivity, contains('getVehicleTrackingDatabasePath'));
      expect(mainActivity, contains('updateVehicleTrackingSyncConfig'));
      expect(mainActivity, contains('flutter.vehicle_profile'));
      expect(mainActivity, contains('startVehicleTrackingService'));
      expect(mainActivity, contains('stopVehicleTrackingService'));
      expect(bootReceiver, contains('VehicleTrackingService.ACTION_START'));
    },
  );
}

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

class _StubHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(const []),
      200,
    );
  }
}

class _CapturingHttpClient extends http.BaseClient {
  _CapturingHttpClient({
    String responseBody = '',
    List<_FakeHttpResponse>? responses,
  }) : _responses = responses ?? [_FakeHttpResponse(200, responseBody)];

  final List<_FakeHttpResponse> _responses;
  Map<String, String>? lastHeaders;
  String? lastBody;
  Uri? lastUrl;
  final requestUrls = <Uri>[];
  final requestBodies = <String>[];
  int _responseIndex = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastHeaders = request.headers;
    lastUrl = request.url;
    requestUrls.add(request.url);
    if (request is http.Request) {
      lastBody = request.body;
      requestBodies.add(request.body);
    } else {
      requestBodies.add('');
    }
    final response =
        _responses[_responseIndex < _responses.length
            ? _responseIndex
            : _responses.length - 1];
    _responseIndex++;
    return http.StreamedResponse(
      Stream<List<int>>.value(response.body.codeUnits),
      response.statusCode,
    );
  }
}

class _FakeHttpResponse {
  const _FakeHttpResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}
