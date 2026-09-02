import 'dart:convert';

import 'package:car_launcher/features/vehicle/data/alert_api_client.dart';
import 'package:car_launcher/features/vehicle/data/alert_repository.dart';
import 'package:car_launcher/features/vehicle/data/geofence_api_client.dart';
import 'package:car_launcher/features/vehicle/data/geofence_repository.dart';
import 'package:car_launcher/features/vehicle/domain/alert_rule.dart';
import 'package:car_launcher/features/vehicle/domain/geofence.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle_alert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _endpoint = 'https://car-apis.202corp.com/vehicle-service';

void main() {
  group('GeofenceRepository', () {
    test('createGeofence POSTs the create body and parses the response',
        () async {
      late http.Request req;
      final repo = GeofenceRepository(
        apiClient: GeofenceApiClient(
          httpClient: MockClient((r) async {
            req = r;
            return http.Response(
              jsonEncode({
                'id': 'g-1',
                'name': 'Depot',
                'shapeType': 'CIRCLE',
                'centerLat': 10.0,
                'centerLon': 106.0,
                'radiusMeters': 150.0,
                'active': true,
              }),
              201,
            );
          }),
        ),
        syncEndpoint: _endpoint,
      );

      final created = await repo.createGeofence(
        const Geofence(
          name: 'Depot',
          shape: GeofenceShape.circle,
          centerLat: 10,
          centerLon: 106,
          radiusMeters: 150,
        ),
      );

      expect(req.method, 'POST');
      expect(req.url.path, endsWith('/client-api/v1/geofences'));
      expect(jsonDecode(req.body)['shapeType'], 'CIRCLE');
      expect(created.id, 'g-1');
      expect(created.radiusMeters, 150.0);
    });

    test('listGeofences forwards the vehicleId filter', () async {
      late Uri seen;
      final repo = GeofenceRepository(
        apiClient: GeofenceApiClient(
          httpClient: MockClient((r) async {
            seen = r.url;
            return http.Response(jsonEncode({'items': []}), 200);
          }),
        ),
        syncEndpoint: _endpoint,
      );
      await repo.listGeofences(vehicleId: 'car-001');
      expect(seen.queryParameters['vehicleId'], 'car-001');
    });
  });

  group('AlertRepository', () {
    test('listAlerts maps items and forwards filters', () async {
      late Uri seen;
      final repo = AlertRepository(
        apiClient: AlertApiClient(
          httpClient: MockClient((r) async {
            seen = r.url;
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 'a-1',
                    'type': 'IDLE',
                    'status': 'OPEN',
                    'message': 'Idle 20m',
                    'peakValue': 20.0,
                  },
                ],
              }),
              200,
            );
          }),
        ),
        syncEndpoint: _endpoint,
      );

      final alerts = await repo.listAlerts(
        vehicleId: 'car-001',
        type: AlertType.idle,
        status: AlertStatus.open,
      );
      expect(seen.queryParameters['type'], 'IDLE');
      expect(seen.queryParameters['status'], 'OPEN');
      expect(alerts.single.type, AlertType.idle);
    });

    test('resolveAlert POSTs to /alerts/{id}/resolve', () async {
      late http.Request req;
      final repo = AlertRepository(
        apiClient: AlertApiClient(
          httpClient: MockClient((r) async {
            req = r;
            return http.Response(
              jsonEncode({'id': 'a-1', 'status': 'RESOLVED', 'type': 'IDLE'}),
              200,
            );
          }),
        ),
        syncEndpoint: _endpoint,
      );
      final resolved = await repo.resolveAlert('a-1');
      expect(req.method, 'POST');
      expect(req.url.path, endsWith('/client-api/v1/alerts/a-1/resolve'));
      expect(resolved.status, AlertStatus.resolved);
    });

    test('createRule sends the overspeed body', () async {
      late http.Request req;
      final repo = AlertRepository(
        apiClient: AlertApiClient(
          httpClient: MockClient((r) async {
            req = r;
            return http.Response(
              jsonEncode({
                'id': 'r-1',
                'type': 'OVERSPEED',
                'speedLimitKph': 80.0,
                'active': true,
              }),
              201,
            );
          }),
        ),
        syncEndpoint: _endpoint,
      );
      final rule = await repo.createRule(
        const AlertRule(type: AlertType.overspeed, speedLimitKph: 80),
      );
      expect(jsonDecode(req.body)['speedLimitKph'], 80);
      expect(rule.id, 'r-1');
    });
  });
}
