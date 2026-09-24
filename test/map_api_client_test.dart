import 'dart:convert';

import 'package:car_launcher/features/vehicle/data/map_api_client.dart';
import 'package:car_launcher/features/vehicle/data/map_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _endpoint = 'https://car-apis.202corp.com/vehicle-service';

void main() {
  group('MapApiClient / MapRepository', () {
    test('getRoute hits the route path and parses the polyline', () async {
      late Uri seen;
      final repo = MapRepository(
        apiClient: MapApiClient(
          httpClient: MockClient((req) async {
            seen = req.url;
            return http.Response(
              jsonEncode({
                'vehicleId': 'car-001',
                'rawCount': 100,
                'simplifiedCount': 3,
                'distanceMeters': 4500.0,
                'points': [
                  {'latitude': 10.0, 'longitude': 106.0},
                  {'latitude': 10.05, 'longitude': 106.02},
                  {'latitude': 10.1, 'longitude': 106.05},
                ],
              }),
              200,
            );
          }),
        ),
        syncEndpoint: _endpoint,
      );

      final route = await repo.getRoute('car-001');
      expect(
        seen.path,
        endsWith('/client-api/v1/vehicles/car-001/tracking-points/route'),
      );
      expect(route.points, hasLength(3));
      expect(route.hasPath, isTrue);
      expect(route.distanceKm, 4.5);
    });

    test('reverseGeocode returns null on 503 (provider not configured)',
        () async {
      final repo = MapRepository(
        apiClient: MapApiClient(
          httpClient: MockClient((req) async => http.Response('', 503)),
        ),
        syncEndpoint: _endpoint,
      );
      expect(await repo.reverseGeocode(10, 106), isNull);
    });

    test('reverseGeocode returns null when displayName is blank', () async {
      final repo = MapRepository(
        apiClient: MapApiClient(
          httpClient: MockClient(
            (req) async => http.Response(jsonEncode({'displayName': ''}), 200),
          ),
        ),
        syncEndpoint: _endpoint,
      );
      expect(await repo.reverseGeocode(10, 106), isNull);
    });

    test('reverseGeocode parses a real address', () async {
      final repo = MapRepository(
        apiClient: MapApiClient(
          httpClient: MockClient(
            (req) async => http.Response(
              jsonEncode({'displayName': 'Hanoi, Vietnam'}),
              200,
            ),
          ),
        ),
        syncEndpoint: _endpoint,
      );
      final result = await repo.reverseGeocode(21.02, 105.83);
      expect(result?.displayName, 'Hanoi, Vietnam');
    });
  });
}
