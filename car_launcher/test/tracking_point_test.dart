import 'package:car_launcher/features/vehicle/domain/tracking_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrackingPoint', () {
    test('fromJson handles all fields correctly', () {
      final point = TrackingPoint.fromJson({
        'id': 'uuid-1',
        'vehicleId': 'car-001',
        'latitude': 10.5,
        'longitude': 106.5,
        'speedKph': 55.5,
        'heading': 270.0,
        'accuracyMeters': 3.5,
        'altitudeMeters': 15.0,
        'ignitionOn': true,
        'eventTime': '2026-06-25T12:00:00.000Z',
        'metadata': {'clientPointId': 'abc', 'displayName': 'Home'},
        'deviceId': 'dev-1',
      });
      expect(point.id, 'uuid-1');
      expect(point.vehicleId, 'car-001');
      expect(point.latitude, 10.5);
      expect(point.longitude, 106.5);
      expect(point.speedKph, 55.5);
      expect(point.heading, 270.0);
      expect(point.accuracyMeters, 3.5);
      expect(point.altitudeMeters, 15.0);
      expect(point.ignitionOn, isTrue);
      expect(point.eventTime.toIso8601String(), '2026-06-25T12:00:00.000Z');
      expect(point.metadata['clientPointId'], 'abc');
      expect(point.metadata['displayName'], 'Home');
      expect(point.deviceId, 'dev-1');
    });

    test('fromJson handles integer numeric values', () {
      // API might return 10 instead of 10.0
      final point = TrackingPoint.fromJson({
        'id': 'uuid-1',
        'latitude': 10,
        'longitude': 106,
        'speedKph': 50,
        'heading': 180,
        'eventTime': '2026-06-25T12:00:00.000Z',
      });
      expect(point.latitude, 10.0);
      expect(point.longitude, 106.0);
      expect(point.speedKph, 50.0);
      expect(point.heading, 180.0);
    });

    test('fromJson handles missing id', () {
      final point = TrackingPoint.fromJson({
        'latitude': 10.0,
        'longitude': 106.0,
        'eventTime': '2026-06-25T12:00:00.000Z',
      });
      expect(point.id, isEmpty);
    });

    test('fromJson handles invalid eventTime gracefully', () {
      final point = TrackingPoint.fromJson({
        'id': 'uuid-1',
        'latitude': 10.0,
        'longitude': 106.0,
        'eventTime': 'not-a-date',
      });
      // Falls back to epoch
      expect(point.eventTime.year, 1970);
    });

    test('fromJson handles missing eventTime', () {
      final point = TrackingPoint.fromJson({
        'id': 'uuid-1',
        'latitude': 10.0,
        'longitude': 106.0,
      });
      expect(point.eventTime.millisecondsSinceEpoch, 0);
    });

    test('fromJson handles null metadata', () {
      final point = TrackingPoint.fromJson({
        'id': 'uuid-1',
        'latitude': 10.0,
        'longitude': 106.0,
        'eventTime': '2026-06-25T12:00:00.000Z',
        'metadata': null,
      });
      expect(point.metadata, isEmpty);
    });

    test('fromJson handles metadata with non-String keys', () {
      // JSON decode always produces String keys, but be defensive
      final point = TrackingPoint.fromJson({
        'id': 'uuid-1',
        'latitude': 10.0,
        'longitude': 106.0,
        'eventTime': '2026-06-25T12:00:00.000Z',
        'metadata': {'key': 'value'},
      });
      expect(point.metadata['key'], 'value');
    });

    test('toJson includes all non-null fields', () {
      final point = TrackingPoint(
        id: 'uuid-1',
        vehicleId: 'car-001',
        latitude: 10.5,
        longitude: 106.5,
        speedKph: 55.5,
        heading: 270.0,
        accuracyMeters: 3.5,
        altitudeMeters: 15.0,
        ignitionOn: true,
        eventTime: DateTime.parse('2026-06-25T12:00:00.000Z'),
        metadata: {'clientPointId': 'abc'},
        deviceId: 'dev-1',
      );
      final json = point.toJson();
      expect(json['id'], 'uuid-1');
      expect(json['vehicleId'], 'car-001');
      expect(json['latitude'], 10.5);
      expect(json['longitude'], 106.5);
      expect(json['speedKph'], 55.5);
      expect(json['heading'], 270.0);
      expect(json['accuracyMeters'], 3.5);
      expect(json['altitudeMeters'], 15.0);
      expect(json['ignitionOn'], isTrue);
      expect(json['eventTime'], '2026-06-25T12:00:00.000Z');
      expect(json['metadata'], {'clientPointId': 'abc'});
      expect(json['deviceId'], 'dev-1');
    });

    test('toJson omits empty/null optional fields', () {
      final point = TrackingPoint(
        id: 'uuid-1',
        latitude: 10.0,
        longitude: 106.0,
        eventTime: DateTime.parse('2026-06-25T12:00:00.000Z'),
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

    test('toJson serializes eventTime as UTC ISO8601', () {
      final point = TrackingPoint(
        id: 'uuid-1',
        latitude: 10.0,
        longitude: 106.0,
        eventTime: DateTime.utc(2026, 6, 25, 14, 30, 0),
      );
      final json = point.toJson();
      expect(json['eventTime'], '2026-06-25T14:30:00.000Z');
    });

    test('toLocationJson returns only lat/lon', () {
      final point = TrackingPoint(
        id: 'uuid-1',
        latitude: 10.5,
        longitude: 106.5,
        eventTime: DateTime.utc(2026),
      );
      final json = point.toLocationJson();
      expect(json, {'latitude': 10.5, 'longitude': 106.5});
    });

    test('equality is based on id, vehicleId, latitude, longitude, eventTime',
        () {
      final a = TrackingPoint(
        id: 'same',
        vehicleId: 'car-001',
        latitude: 10.0,
        longitude: 106.0,
        eventTime: DateTime.utc(2026, 6, 25),
      );
      final b = TrackingPoint(
        id: 'same',
        vehicleId: 'car-001',
        latitude: 10.0,
        longitude: 106.0,
        eventTime: DateTime.utc(2026, 6, 25),
        speedKph: 50.0, // different, but not in equality
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when core fields differ', () {
      final a = TrackingPoint(
        id: 'id-1',
        latitude: 10.0,
        longitude: 106.0,
        eventTime: DateTime.utc(2026),
      );
      final b = TrackingPoint(
        id: 'id-2',
        latitude: 10.0,
        longitude: 106.0,
        eventTime: DateTime.utc(2026),
      );
      expect(a, isNot(equals(b)));
    });

    test('toString includes id, lat, lon, eventTime', () {
      final point = TrackingPoint(
        id: 'uuid-1',
        latitude: 10.5,
        longitude: 106.5,
        eventTime: DateTime.utc(2026, 6, 25, 12, 0),
      );
      final str = point.toString();
      expect(str, contains('uuid-1'));
      expect(str, contains('10.5'));
      expect(str, contains('106.5'));
    });

    test('speedKph zero is different from null', () {
      final withZero = TrackingPoint(
        id: 'id-1',
        latitude: 10.0,
        longitude: 106.0,
        eventTime: DateTime.utc(2026),
        speedKph: 0.0,
      );
      final withNull = TrackingPoint(
        id: 'id-1',
        latitude: 10.0,
        longitude: 106.0,
        eventTime: DateTime.utc(2026),
      );
      expect(withZero.speedKph, 0.0);
      expect(withNull.speedKph, isNull);
    });

    test('ignitionOn false is different from null', () {
      final off = TrackingPoint(
        id: 'id-1',
        latitude: 10.0,
        longitude: 106.0,
        eventTime: DateTime.utc(2026),
        ignitionOn: false,
      );
      final unknown = TrackingPoint(
        id: 'id-1',
        latitude: 10.0,
        longitude: 106.0,
        eventTime: DateTime.utc(2026),
      );
      expect(off.ignitionOn, isFalse);
      expect(unknown.ignitionOn, isNull);
    });
  });
}
