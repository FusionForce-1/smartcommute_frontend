import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/models/transport_stop.dart';
import 'package:smartcommute_app/widgets/stop_search_sheet.dart';

TransportStop stop(String id, String name, {String? landmark}) => TransportStop(
      id: id,
      name: name,
      location: const LatLng(10.3, 123.9),
      routeIds: const ['r1'],
      sequence: 1,
      landmark: landmark,
    );

void main() {
  final stops = [
    stop('1', 'Colon Street'),
    stop('2', 'IT Park Terminal', landmark: 'Near Ayala Central Bloc'),
    stop('3', 'SM City Cebu'),
  ];

  test('blank or whitespace query returns all stops', () {
    expect(filterStops(stops, ''), stops);
    expect(filterStops(stops, '   '), stops);
  });

  test('matches name case-insensitively and trims', () {
    expect(filterStops(stops, '  colon ').map((s) => s.id), ['1']);
  });

  test('matches landmark text', () {
    expect(filterStops(stops, 'ayala').map((s) => s.id), ['2']);
  });

  test('no match returns empty', () {
    expect(filterStops(stops, 'talamban'), isEmpty);
  });
}
