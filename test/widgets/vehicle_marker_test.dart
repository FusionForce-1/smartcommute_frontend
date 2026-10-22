import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/models/vehicle_live_update.dart';
import 'package:smartcommute_app/widgets/commuter/vehicle_marker.dart';

Widget host(Widget child) => MaterialApp(home: Center(child: SizedBox(width: 50, height: 50, child: child)));

void main() {
  const live = VehicleLiveUpdate(vehicleId: 'v', status: 'en_route');

  testWidgets('a parked PUV shows the vehicle icon, upright', (tester) async {
    await tester.pumpWidget(host(const VehicleMarker(vehicle: live)));
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(Transform), findsNothing);
  });

  testWidgets('a moving PUV turns to face its heading', (tester) async {
    await tester.pumpWidget(host(const VehicleMarker(vehicle: live, heading: 90)));
    final rotate = tester.widget<Transform>(find.ancestor(of: find.byType(SvgPicture), matching: find.byType(Transform)).first);
    expect(rotate.transform.getRotation().entry(0, 1), closeTo(-1, 1e-6)); // 90° clockwise
  });

  testWidgets('signal lost greys the PUV out', (tester) async {
    await tester.pumpWidget(host(const VehicleMarker(vehicle: VehicleLiveUpdate(vehicleId: 'v', status: 'signal_lost'))));
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  test('a shift_ended frame is recognised', () {
    final u = VehicleLiveUpdate.fromJson({'vehicle_id': 'v', 'status': 'signal_lost', 'shift_ended': true});
    expect(u.shiftEnded, isTrue);
    expect(VehicleLiveUpdate.fromJson({'vehicle_id': 'v', 'status': 'en_route'}).shiftEnded, isFalse);
  });
}
