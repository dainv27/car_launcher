import 'dart:convert';

import 'package:car_launcher/core/api/api_response.dart';
import 'package:car_launcher/features/vehicle/data/trip_api_client.dart';
import 'package:car_launcher/features/vehicle/data/trip_repository.dart';
import 'package:car_launcher/features/vehicle/domain/trip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _endpoint = 'https://car-apis.202corp.com/vehicle-service';

void main() {
  group('TripApiClient', () {
    test('listTrips hits the vehicle-scoped path with query params', () async {
      late Uri seen;
      final client = TripApiClient(
        httpClient: MockClient((req) async {
          seen = req.url;
          return http.Response(jsonEncode({'items': []}), 200);
        }),
      );

      await client.listTrips(
        endpoint: _endpoint,
        vehicleId: 'car-001',
        status: 'CLOSED',
        page: 1,
        size: 10,
      );

      expect(seen.path, endsWith('/client-api/v1/vehicles/car-001/trips'));
      expect(seen.queryParameters['status'], 'CLOSED');
      expect(seen.queryParameters['page'], '1');
      expect(seen.queryParameters['size'], '10');
    });

    test('getTrip unwraps a { trip: {...} } envelope', () async {
      final client = TripApiClient(
        httpClient: MockClient((req) async => http.Response(
              jsonEncode({
                'trip': {'id': 't-9', 'status': 'OPEN'}
              }),
              200,
            )),
      );
      final json = await client.getTrip(endpoint: _endpoint, tripId: 't-9');
      expect(json['id'], 't-9');
    });

    test('non-2xx throws ApiException', () async {
      final client = TripApiClient(
        httpClient: MockClient((req) async => http.Response('nope', 500)),
      );
      expect(
        () => client.listTrips(endpoint: _endpoint, vehicleId: 'car-001'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('TripRepository', () {
    test('listTrips maps items to Trip domain objects', () async {
      final repo = TripRepository(
        apiClient: TripApiClient(
          httpClient: MockClient((req) async => http.Response(
                jsonEncode({
                  'items': [
                    {
                      'id': 't-1',
                      'status': 'CLOSED',
                      'distanceMeters': 5000.0,
                      'durationSeconds': 600,
                    },
                  ],
                }),
                200,
              )),
        ),
        syncEndpoint: _endpoint,
      );
      final trips = await repo.listTrips('car-001');
      expect(trips, hasLength(1));
      expect(trips.first.status, TripStatus.closed);
      expect(trips.first.distanceKm, 5.0);
    });

    test('empty vehicleId short-circuits without a request', () async {
      var called = false;
      final repo = TripRepository(
        apiClient: TripApiClient(
          httpClient: MockClient((req) async {
            called = true;
            return http.Response('[]', 200);
          }),
        ),
        syncEndpoint: _endpoint,
      );
      expect(await repo.listTrips(''), isEmpty);
      expect(called, isFalse);
    });
  });
}
