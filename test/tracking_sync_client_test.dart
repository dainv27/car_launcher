import 'dart:convert';

import 'package:car_launcher/features/tracking/data/tracking_sync_client.dart';
import 'package:car_launcher/features/tracking/domain/vehicle_track_point.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _testEndpoint =
    'https://car-apis.202corp.com/vehicle-service/client-api/v1';
const _publicEndpoint =
    'https://car-apis.202corp.com/vehicle-service/public-api/v1';

void main() {
  group('TrackingSyncClient', () {
    test('sync throws if vehicleId is empty', () async {
      final client = TrackingSyncClient(
        httpClient: MockClient((req) async => http.Response('', 200)),
      );
      expect(
        client.sync(
          endpoint: _testEndpoint,
          points: [],
          vehicle: const Vehicle(id: ''),
        ),
        throwsStateError,
      );
    });

    test('sync throws on non-2xx response', () async {
      final client = TrackingSyncClient(
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
          vehicle: const Vehicle(id: 'car-001'),
        ),
        throwsStateError,
      );
    });

    test('sync throws a linkage error on 409', () async {
      final client = TrackingSyncClient(
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
          vehicle: const Vehicle(id: 'car-001'),
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
      final client = TrackingSyncClient(
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
        vehicle: const Vehicle(id: 'car-001'),
      );
      expect(urls, ['$_publicEndpoint/devices/me/tracking-points']);
    });

    test('getLatestTrackingPoint throws on non-2xx/204 response', () async {
      final client = TrackingSyncClient(
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
      final client = TrackingSyncClient(
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
      final contentClient = TrackingSyncClient(
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
      final dataClient = TrackingSyncClient(
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
      final itemsClient = TrackingSyncClient(
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
      final tpClient = TrackingSyncClient(
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
      final client = TrackingSyncClient(
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
      final client = TrackingSyncClient(
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
  });
}
