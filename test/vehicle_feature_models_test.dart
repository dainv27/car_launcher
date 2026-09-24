import 'package:car_launcher/features/vehicle/domain/alert_rule.dart';
import 'package:car_launcher/features/vehicle/domain/geo_point.dart';
import 'package:car_launcher/features/vehicle/domain/geofence.dart';
import 'package:car_launcher/features/vehicle/domain/geofence_event.dart';
import 'package:car_launcher/features/vehicle/domain/tracking_route.dart';
import 'package:car_launcher/features/vehicle/domain/trip.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle_alert.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Trip', () {
    test('fromJson parses stats and enums', () {
      final trip = Trip.fromJson({
        'id': 't-1',
        'vehicleId': 'car-001',
        'status': 'CLOSED',
        'startTime': '2026-06-22T08:00:00.000Z',
        'endTime': '2026-06-22T08:30:00.000Z',
        'distanceMeters': 12000.0,
        'durationSeconds': 1800,
        'avgSpeedKph': 24.0,
        'maxSpeedKph': 61.0,
        'pointCount': 240,
        'closeReason': 'IGNITION_OFF',
      });
      expect(trip.status, TripStatus.closed);
      expect(trip.isOpen, isFalse);
      expect(trip.distanceKm, 12.0);
      expect(trip.duration, const Duration(minutes: 30));
      expect(trip.closeReason, TripCloseReason.ignitionOff);
      expect(trip.closeReason!.label, 'Ignition off');
    });

    test('unknown status falls back to closed; missing closeReason is null', () {
      final trip = Trip.fromJson({'id': 't-2', 'status': 'WEIRD'});
      expect(trip.status, TripStatus.closed);
      expect(trip.closeReason, isNull);
      expect(trip.distanceKm, 0);
    });
  });

  group('TrackingRoute', () {
    test('fromJson parses points and flags', () {
      final route = TrackingRoute.fromJson({
        'vehicleId': 'car-001',
        'rawCount': 500,
        'simplifiedCount': 2,
        'distanceMeters': 3200.0,
        'points': [
          {'latitude': 10.0, 'longitude': 106.0, 'speedKph': 0.0},
          {'latitude': 10.1, 'longitude': 106.1},
        ],
      });
      expect(route.points, hasLength(2));
      expect(route.hasPath, isTrue);
      expect(route.distanceKm, 3.2);
      expect(route.points.first.latitude, 10.0);
    });

    test('empty points => isEmpty, not a path', () {
      final route = TrackingRoute.fromJson({'points': []});
      expect(route.isEmpty, isTrue);
      expect(route.hasPath, isFalse);
    });
  });

  group('Geofence', () {
    test('circle round-trips through toCreateJson', () {
      const g = Geofence(
        vehicleId: 'car-001',
        name: 'Depot',
        shape: GeofenceShape.circle,
        centerLat: 10.0,
        centerLon: 106.0,
        radiusMeters: 150,
      );
      final json = g.toCreateJson();
      expect(json['shapeType'], 'CIRCLE');
      expect(json['centerLat'], 10.0);
      expect(json['radiusMeters'], 150);
      expect(json.containsKey('polygon'), isFalse);
      expect(json['vehicleId'], 'car-001');
    });

    test('polygon toCreateJson serialises the ring; fromJson reads it back', () {
      const g = Geofence(
        name: 'Yard',
        shape: GeofenceShape.polygon,
        polygon: [GeoPoint(1, 1), GeoPoint(1, 2), GeoPoint(2, 2)],
      );
      final json = g.toCreateJson();
      expect(json['shapeType'], 'POLYGON');
      expect((json['polygon'] as List), hasLength(3));
      expect(json.containsKey('centerLat'), isFalse);
      expect(json.containsKey('vehicleId'), isFalse);

      final parsed = Geofence.fromJson({
        'id': 'g-1',
        'name': 'Yard',
        'shapeType': 'POLYGON',
        'polygon': json['polygon'],
        'active': true,
      });
      expect(parsed.polygon, hasLength(3));
      expect(parsed.polygon[1], const GeoPoint(1, 2));
    });

    test('copyWith can clear vehicleId via explicit null', () {
      const g = Geofence(id: 'g-1', vehicleId: 'car-001', name: 'x');
      expect(g.copyWith(name: 'y').vehicleId, 'car-001');
      expect(g.copyWith(vehicleId: null).vehicleId, isNull);
    });
  });

  group('GeofenceEvent', () {
    test('fromJson parses transition', () {
      final e = GeofenceEvent.fromJson({
        'id': 'e-1',
        'geofenceName': 'Depot',
        'transition': 'EXIT',
        'eventTime': '2026-06-22T09:00:00.000Z',
      });
      expect(e.transition, GeofenceTransition.exit);
      expect(e.geofenceName, 'Depot');
    });
  });

  group('AlertRule', () {
    test('overspeed toCreateJson only carries speed fields', () {
      const r = AlertRule(
        vehicleId: 'car-001',
        type: AlertType.overspeed,
        speedLimitKph: 80,
        minDurationSeconds: 10,
      );
      final json = r.toCreateJson();
      expect(json['type'], 'OVERSPEED');
      expect(json['speedLimitKph'], 80);
      expect(json['minDurationSeconds'], 10);
      expect(json.containsKey('idleMinutes'), isFalse);
    });

    test('idle toCreateJson only carries idleMinutes', () {
      const r = AlertRule(type: AlertType.idle, idleMinutes: 15);
      final json = r.toCreateJson();
      expect(json['type'], 'IDLE');
      expect(json['idleMinutes'], 15);
      expect(json.containsKey('speedLimitKph'), isFalse);
      expect(json.containsKey('vehicleId'), isFalse);
    });
  });

  group('VehicleAlert', () {
    test('fromJson parses status/type/peak', () {
      final a = VehicleAlert.fromJson({
        'id': 'a-1',
        'type': 'OVERSPEED',
        'status': 'OPEN',
        'message': 'Went 92 in an 80 zone',
        'peakValue': 92.0,
        'startedAt': '2026-06-22T10:00:00.000Z',
      });
      expect(a.type, AlertType.overspeed);
      expect(a.status, AlertStatus.open);
      expect(a.isOpen, isTrue);
      expect(a.peakValue, 92.0);
    });
  });
}
