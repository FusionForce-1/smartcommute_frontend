import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/constants/app_icons.dart';
import 'package:smartcommute_app/widgets/commuter/commuter_action_tile.dart';
import 'package:smartcommute_app/widgets/commuter/commuter_nav_bar.dart';
import 'package:smartcommute_app/widgets/commuter/nearby_vehicle_card.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('CommuterNavBar', () {
    const items = [
      CommuterNavItem(icon: AppIcons.navHome, label: 'Home'),
      CommuterNavItem(icon: AppIcons.navRoute, label: 'Route'),
      CommuterNavItem(icon: AppIcons.navAlerts, label: 'Alerts'),
      CommuterNavItem(icon: AppIcons.navProfile, label: 'Profile'),
    ];

    testWidgets('shows every tab and reports the tapped index', (tester) async {
      int? tapped;
      await tester.pumpWidget(host(CommuterNavBar(
        items: items,
        selectedIndex: 0,
        onSelected: (i) => tapped = i,
      )));

      for (final item in items) {
        expect(find.text(item.label), findsOneWidget);
      }
      await tester.tap(find.text('Alerts'));
      expect(tapped, 2);
    });

    testWidgets('marks only the selected tab as selected', (tester) async {
      await tester.pumpWidget(host(CommuterNavBar(
        items: items,
        selectedIndex: 1,
        onSelected: (_) {},
      )));

      final selected = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.selected == true)
          .toList();
      expect(selected, hasLength(1));
      expect(
        find.descendant(of: find.byWidget(selected.single), matching: find.text('Route')),
        findsOneWidget,
      );
    });
  });

  group('NearbyVehicleCard', () {
    testWidgets('shows code, PUV label, route name and ETA', (tester) async {
      await tester.pumpWidget(host(const NearbyVehicleCard(
        routeCode: '07B',
        routeName: 'Banawa → Carbon',
        etaMinutes: 3,
      )));

      expect(find.text('07B'), findsOneWidget);
      expect(find.text('PUV 07B'), findsOneWidget);
      expect(find.text('Banawa → Carbon'), findsOneWidget);
      expect(find.text('~3 min'), findsOneWidget);
    });

    testWidgets('hides the ETA when it is unknown', (tester) async {
      await tester.pumpWidget(host(const NearbyVehicleCard(
        routeCode: '07B',
        routeName: 'Banawa → Carbon',
      )));

      expect(find.textContaining('min'), findsNothing);
    });
  });

  testWidgets('CommuterActionTile ignores taps when disabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(Column(children: [
      CommuterActionTile(icon: AppIcons.settings, label: 'On', onTap: () => taps++),
      CommuterActionTile(
        icon: AppIcons.settings,
        label: 'Off',
        enabled: false,
        onTap: () => taps++,
      ),
    ])));

    await tester.tap(find.text('On'));
    await tester.tap(find.text('Off'));
    expect(taps, 1);
  });
}
