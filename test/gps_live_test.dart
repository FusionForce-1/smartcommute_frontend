import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smartcommute_app/models/models.dart';
import 'package:smartcommute_app/models/vehicle_live_update.dart';
import 'package:smartcommute_app/services/websocket_service.dart';

// Frames shaped exactly like app/websockets/gps_ingestion.py broadcasts
// them (json.dumps(..., default=str) turns datetimes into "YYYY-MM-DD HH:MM:SS").
Map<String, dynamic> frame(String ts, {double lat = 10.3, double lng = 123.9}) => {
      'vehicle_id': 'v1',
      'lat': lat,
      'lng': lng,
      'speed': 32.5,
      'heading': 90.0,
      'ts': ts,
      'status': 'en_route',
      'crowd': 'low',
      'eta_next_stop': 4,
    };

void main() {
  group('parseServerTime', () {
    test('naive Python datetime is treated as UTC', () {
      expect(parseServerTime('2026-09-30 04:00:00.123456'),
          DateTime.utc(2026, 9, 30, 4, 0, 0, 123, 456));
    });
    test('offset-aware ISO string', () {
      expect(parseServerTime('2026-09-30 12:00:00+08:00'),
          DateTime.utc(2026, 9, 30, 4));
    });
    test('exact ts format seen from the live backend', () {
      expect(parseServerTime('2026-09-30 10:26:40.117924+00:00'),
          DateTime.utc(2026, 9, 30, 10, 26, 40, 117, 924));
    });
    test('garbage and null', () {
      expect(parseServerTime(null), isNull);
      expect(parseServerTime('nope'), isNull);
    });
  });

  group('VehicleLiveUpdate', () {
    test('parses broadcast frame including speed/heading/ts', () {
      final u = VehicleLiveUpdate.fromJson(frame('2026-09-30 04:00:00'));
      expect(u.location!.latitude, 10.3);
      expect(u.speed, 32.5);
      expect(u.heading, 90.0);
      expect(u.timestamp, DateTime.utc(2026, 9, 30, 4));
      expect(u.isSignalLost, isFalse);
    });

    test('signal_lost keeps last known position', () {
      final live = VehicleLiveUpdate.fromJson(frame('2026-09-30 04:00:00'));
      final lost = VehicleLiveUpdate.fromJson({
        'vehicle_id': 'v1',
        'status': 'signal_lost',
        'crowd': 'low',
        'eta_next_stop': -1,
      });
      final merged = live.merge(lost)!;
      expect(merged.isSignalLost, isTrue);
      expect(merged.location, live.location);
    });

    test('frames resuming after signal_lost flip back to en_route', () {
      final lost = VehicleLiveUpdate.fromJson(frame('2026-09-30 04:00:00'))
          .merge(VehicleLiveUpdate.fromJson(
              {'vehicle_id': 'v1', 'status': 'signal_lost'}))!;
      final resumed = lost.merge(
          VehicleLiveUpdate.fromJson(frame('2026-09-30 04:00:45', lat: 10.4)))!;
      expect(resumed.isSignalLost, isFalse);
      expect(resumed.location!.latitude, 10.4);
    });

    test('older fix arriving late is dropped', () {
      final newer = VehicleLiveUpdate.fromJson(frame('2026-09-30 04:00:10'));
      final older = VehicleLiveUpdate.fromJson(frame('2026-09-30 04:00:05'));
      expect(newer.merge(older), isNull);
    });
  });

  test('GPSPositionModel parses GET /vehicles/{id}/position (GeoJSON)', () {
    final p = GPSPositionModel.fromJson({
      'vehicle_id': 'v1',
      'location': {'type': 'Point', 'coordinates': [123.9, 10.3]},
      'speed': 20,
      'heading': null,
      'timestamp': '2026-09-30T04:00:00',
    });
    expect(p.lat, 10.3);
    expect(p.lng, 123.9);
    expect(p.speed, 20.0);
    expect(p.timestamp, DateTime.utc(2026, 9, 30, 4));
  });

  test('driver frame matches backend JSON contract', () {
    final fix = Position(
      latitude: 10.3,
      longitude: 123.9,
      timestamp: DateTime.utc(2026, 9, 30, 4),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 180,
      headingAccuracy: 0,
      speed: 10, // m/s
      speedAccuracy: 0,
    );
    expect(GpsIngestionSession.encodeFix(fix), {
      'lat': 10.3,
      'lng': 123.9,
      'spd': 36.0, // km/h
      'hdg': 180.0,
      'ts': '2026-09-30T04:00:00.000Z',
    });

    final unknown = Position(
      latitude: 1,
      longitude: 2,
      timestamp: DateTime.utc(2026),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: -1,
      headingAccuracy: 0,
      speed: -1,
      speedAccuracy: 0,
    );
    final f = GpsIngestionSession.encodeFix(unknown);
    expect(f['spd'], isNull);
    expect(f['hdg'], isNull);
  });

  test('driver distance adds up the hops between frames sent', () {
    Position at(double lat) => Position(
          latitude: lat,
          longitude: 123.9,
          timestamp: DateTime.utc(2026, 9, 30, 4),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
    final session = GpsIngestionSession(accessToken: () async => null);

    session.countSent(at(10.3));
    session.countSent(at(10.3)); // keepalive re-sends the same fix
    session.countSent(at(10.3 + 1 / 111.195)); // ~1 km north
    expect(session.distanceMetres, closeTo(1000, 5));

    session.resetDistance();
    session.countSent(at(10.4)); // nothing to measure from
    expect(session.distanceMetres, 0);
  });
}
