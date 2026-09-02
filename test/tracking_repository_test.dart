import 'dart:convert';

import 'package:car_launcher/shared/data/location_service.dart';
import 'package:car_launcher/shared/data/vehicle_tracking_store_service.dart';
import 'package:car_launcher/features/vehicle/data/tracking_repository.dart';
import 'package:car_launcher/features/vehicle/domain/tracking_point.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _testEndpoint =
    'https://car-apis.202corp.com/vehicle-service/client-api/v1';

void main() {
  group('TrackingRepository', () {
    test('getLatestTrackingPoint returns parsed point on 200', () async {
      final responseBody = jsonEncode({
        'id': 'uuid-1',
        'latitude': 10.0,
        'longitude': 106.0,
        'eventTime': '2026-06-22T12:00:00.000Z',
        'metadata': {'clientPointId': 'abc', 'displayName': 'Garage'},
      });
      final client = VehicleTrackingSyncClient(
        httpClient: _mockClient(body: responseBody),
      );
      final repo = TrackingRepository(
        syncClient: client,
        store: VehicleTrackingStoreService(),
        syncEndpoint: _testEndpoint,
      );
      final point = await repo.getLatestTrackingPoint('car-001');
      expect(point, isNotNull);
      expect(point!.id, 'uuid-1');
      expect(point.latitude, 10.0);
      expect(point.longitude, 106.0);
      expect(point.metadata['displayName'], 'Garage');
    });

    test('getLatestTrackingPoint returns null on 204', () async {
      final client = VehicleTrackingSyncClient(
        httpClient: _mockClient(body: '', status: 204),
      );
      final repo = TrackingRepository(
        syncClient: client,
        store: VehicleTrackingStoreService(),
        syncEndpoint: _testEndpoint,
      );
      final point = await repo.getLatestTrackingPoint('car-001');
      expect(point, isNull);
    });

    test('listTrackingPoints returns parsed list', () async {
      final responseBody = jsonEncode([
        {
          'id': 'uuid-1',
          'latitude': 10.0,
          'longitude': 106.0,
          'eventTime': '2026-06-22T12:00:00.000Z',
        },
        {
          'id': 'uuid-2',
          'latitude': 11.0,
          'longitude': 107.0,
          'eventTime': '2026-06-22T13:00:00.000Z',
        },
      ]);
      final client = VehicleTrackingSyncClient(
        httpClient: _mockClient(body: responseBody),
      );
      final repo = TrackingRepository(
        syncClient: client,
        store: VehicleTrackingStoreService(),
        syncEndpoint: _testEndpoint,
      );
      final points = await repo.listTrackingPoints('car-001');
      expect(points, hasLength(2));
      expect(points[0].id, 'uuid-1');
      expect(points[1].id, 'uuid-2');
    });

    test('listTrackingPoints passes from/to/page/size query params', () async {
      final client = VehicleTrackingSyncClient(
        httpClient: _MockCapturingClient(),
      );
      final repo = TrackingRepository(
        syncClient: client,
        store: VehicleTrackingStoreService(),
        syncEndpoint: _testEndpoint,
      );
      final from = DateTime.parse('2026-06-01T00:00:00.000Z');
      final to = DateTime.parse('2026-06-30T23:59:59.000Z');
      await repo.listTrackingPoints(
        'car-001',
        from: from,
        to: to,
        page: 2,
        size: 25,
      );
      expect(_MockCapturingClient.lastQueryParameters, {
        'from': '2026-06-01T00:00:00.000Z',
        'to': '2026-06-30T23:59:59.000Z',
        'page': '2',
        'size': '25',
      });
      // Reads the current vehicle-scoped client API, not the old
      // device-scoped path.
      expect(_MockCapturingClient.lastPath, contains('vehicles/car-001/tracking-points'));
    });
  });

  group('TrackingPoint domain model', () {
    test('fromJson parses all fields', () {
      final point = TrackingPoint.fromJson({
        'id': 'uuid-1',
        'vehicleId': 'car-001',
        'latitude': 10.0,
        'longitude': 106.0,
        'speedKph': 50.0,
        'heading': 180.0,
        'accuracyMeters': 5.0,
        'altitudeMeters': 100.0,
        'ignitionOn': true,
        'eventTime': '2026-06-22T12:00:00.000Z',
        'metadata': {'clientPointId': 'abc'},
        'deviceId': 'dev-1',
      });
      expect(point.id, 'uuid-1');
      expect(point.vehicleId, 'car-001');
      expect(point.latitude, 10.0);
      expect(point.longitude, 106.0);
      expect(point.speedKph, 50.0);
      expect(point.heading, 180.0);
      expect(point.accuracyMeters, 5.0);
      expect(point.altitudeMeters, 100.0);
      expect(point.ignitionOn, isTrue);
      expect(point.eventTime.toIso8601String(), '2026-06-22T12:00:00.000Z');
      expect(point.metadata['clientPointId'], 'abc');
      expect(point.deviceId, 'dev-1');
    });

    test('fromJson handles missing optional fields', () {
      final point = TrackingPoint.fromJson({
        'id': 'uuid-1',
        'latitude': 10.0,
        'longitude': 106.0,
        'eventTime': '2026-06-22T12:00:00.000Z',
      });
      expect(point.id, 'uuid-1');
      expect(point.vehicleId, isEmpty);
      expect(point.speedKph, isNull);
      expect(point.heading, isNull);
      expect(point.accuracyMeters, isNull);
      expect(point.altitudeMeters, isNull);
      expect(point.ignitionOn, isNull);
      expect(point.metadata, isEmpty);
      expect(point.deviceId, isEmpty);
    });

    test('toJson serializes all fields', () {
      const eventTime = '2026-06-22T12:00:00.000Z';
      final point = TrackingPoint(
        id: 'uuid-1',
        vehicleId: 'car-001',
        latitude: 10.0,
        longitude: 106.0,
        speedKph: 50.0,
        heading: 180.0,
        accuracyMeters: 5.0,
        altitudeMeters: 100.0,
        ignitionOn: true,
        eventTime: DateTime.parse(eventTime),
        metadata: {'clientPointId': 'abc'},
        deviceId: 'dev-1',
      );
      final json = point.toJson();
      expect(json['id'], 'uuid-1');
      expect(json['vehicleId'], 'car-001');
      expect(json['latitude'], 10.0);
      expect(json['longitude'], 106.0);
      expect(json['speedKph'], 50.0);
      expect(json['heading'], 180.0);
      expect(json['accuracyMeters'], 5.0);
      expect(json['altitudeMeters'], 100.0);
      expect(json['ignitionOn'], isTrue);
      expect(json['eventTime'], '2026-06-22T12:00:00.000Z');
      expect(json['metadata'], {'clientPointId': 'abc'});
      expect(json['deviceId'], 'dev-1');
    });

    test('toJson omits null/empty optional fields', () {
      final point = TrackingPoint(
        id: 'uuid-1',
        latitude: 10.0,
        longitude: 106.0,
        eventTime: DateTime.parse('2026-06-22T12:00:00.000Z'),
      );
      final json = point.toJson();
      expect(json.containsKey('vehicleId'), isFalse);
      expect(json.containsKey('speedKph'), isFalse);
      expect(json.containsKey('heading'), isFalse);
      expect(json.containsKey('accuracyMeters'), isFalse);
      expect(json.containsKey('altitudeMeters'), isFalse);
      expect(json.containsKey('ignitionOn'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
      expect(json.containsKey('deviceId'), isFalse);
    });
  });
}

/// Mock HTTP client that returns a fixed body/status.
http.Client _mockClient({required String body, int status = 200}) {
  return MockClient((request) async => http.Response(body, status));
}

/// Capturing client that records the last request URI.
class _MockCapturingClient extends http.BaseClient {
  static Map<String, String>? lastQueryParameters;
  static String? lastPath;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastQueryParameters = request.url.queryParameters;
    lastPath = request.url.path;
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode('[]')),
      200,
    );
  }
}
