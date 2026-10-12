import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/models/commuter_profile.dart';
import 'package:smartcommute_app/models/trip_plan.dart';
import 'package:smartcommute_app/providers/load_state.dart';
import 'package:smartcommute_app/providers/profile_provider.dart';
import 'package:smartcommute_app/services/profile_service.dart';

import '../support/commuter_fixtures.dart';
import '../support/fake_dio.dart';
import '../support/trip_plan_fixtures.dart';

ProfileProvider buildProvider(FakeAdapter backend, {bool isGuest = false}) =>
    ProfileProvider(service: ProfileService(fakeDio(backend)), isGuest: isGuest);

Map<String, Object?> loaded([Map<String, Object?> extra = const {}]) => {
      'GET /users/me': profileJson(),
      'GET /users/me/saved-routes': [savedRouteJson('s1')],
      'GET /users/me/settings': settingsJson(),
      ...extra,
    };

void main() {
  test('load fetches profile, saved routes and notification choices', () async {
    final profile = buildProvider(fakeBackend(loaded()));

    await profile.load();

    expect(profile.state, LoadState.ready);
    expect(profile.profile!.name, 'Juan Dela Cruz');
    expect(profile.profile!.initials, 'JD');
    expect(profile.profile!.stats.trips, 47);
    expect(profile.savedRoutes.single.label, 'Home → Office');
    expect(profile.savedRoutes.single.origin!.latitude, 10.37);
    expect(profile.isEnabled(NotificationPref.routeAlerts), isTrue);
    expect(profile.isEnabled(NotificationPref.promotions), isFalse);
  });

  test('guests load nothing', () async {
    final backend = fakeBackend(loaded());
    final profile = buildProvider(backend, isGuest: true);

    await profile.load();

    expect(backend.requests, isEmpty);
    expect(profile.profile, isNull);
  });

  test('a failed load is an error', () async {
    final profile = buildProvider(fakeBackend(loaded({'GET /users/me': 500})));

    await profile.load();

    expect(profile.state, LoadState.error);
    expect(profile.errorMessage, isNotNull);
  });

  test('rename updates the profile', () async {
    final renamed = {...profileJson(), 'name': 'Juan D. Cruz'};
    final profile = buildProvider(fakeBackend(loaded({'PATCH /users/me': renamed})));
    await profile.load();

    final error = await profile.rename(' Juan D. Cruz ');

    expect(error, isNull);
    expect(profile.profile!.name, 'Juan D. Cruz');
  });

  test('addSavedRoute puts the new route first and bumps the count', () async {
    final backend = fakeBackend(loaded({'POST /users/me/saved-routes': savedRouteJson('s2', label: 'Office → SM')}));
    final profile = buildProvider(backend);
    await profile.load();

    final error = await profile.addSavedRoute(
      label: 'Office → SM',
      routeId: 'r1',
      originName: 'Ayala Center Cebu',
      destinationName: 'SM City Cebu',
    );

    expect(error, isNull);
    expect(profile.savedRoutes.map((r) => r.label), ['Office → SM', 'Home → Office']);
    expect(profile.profile!.stats.savedRoutes, 2);
  });

  test('addSavedRoute reports the backend reason', () async {
    final profile = buildProvider(fakeBackend(loaded({'POST /users/me/saved-routes': 400})));
    await profile.load();

    final error = await profile.addSavedRoute(
      label: 'X', routeId: 'r1', originName: 'A', destinationName: 'B');

    expect(error, 'Request failed');
    expect(profile.savedRoutes, hasLength(1));
  });

  test('removeSavedRoute removes it, and restores it if the backend refuses', () async {
    final ok = buildProvider(fakeBackend(loaded({'DELETE /users/me/saved-routes/s1': null})));
    await ok.load();
    expect(await ok.removeSavedRoute(ok.savedRoutes.single), isNull);
    expect(ok.savedRoutes, isEmpty);
    expect(ok.profile!.stats.savedRoutes, 0);

    final failing = buildProvider(fakeBackend(loaded({'DELETE /users/me/saved-routes/s1': 500})));
    await failing.load();
    expect(await failing.removeSavedRoute(failing.savedRoutes.single), isNotNull);
    expect(failing.savedRoutes, hasLength(1));
    expect(failing.profile!.stats.savedRoutes, 1);
  });

  test('setNotificationPref sends only that choice, and rolls back on failure', () async {
    final backend = fakeBackend(loaded({'PATCH /users/me/settings': settingsJson()}));
    final profile = buildProvider(backend);
    await profile.load();

    expect(await profile.setNotificationPref(NotificationPref.promotions, true), isNull);
    expect(profile.isEnabled(NotificationPref.promotions), isTrue);
    expect(backend.requests.last.data, {'promotions': true});

    final failing = buildProvider(fakeBackend(loaded({'PATCH /users/me/settings': 500})));
    await failing.load();
    expect(await failing.setNotificationPref(NotificationPref.routeAlerts, false), isNotNull);
    expect(failing.isEnabled(NotificationPref.routeAlerts), isTrue);
  });

  test('recordTrip posts the trip and bumps the Trips count', () async {
    final backend = fakeBackend(loaded({'POST /users/me/trips': {}}));
    final profile = buildProvider(backend);
    await profile.load();
    final option = TripPlanResponse.fromJson(sampleResponse()).options.single;

    await profile.recordTrip(option, from: 'Talamban', to: 'IT Park');

    expect(profile.profile!.stats.trips, 48);
    final body = backend.requests.last.data as Map<String, dynamic>;
    expect(jsonEncode(body), contains('"route_ids":["r1","r2"]'));
    expect(body['destination_name'], 'IT Park');
  });

  test('a failed recordTrip is silent and leaves the count', () async {
    final profile = buildProvider(fakeBackend(loaded({'POST /users/me/trips': 500})));
    await profile.load();
    final option = TripPlanResponse.fromJson(sampleResponse()).options.single;

    await profile.recordTrip(option, from: 'A', to: 'B');

    expect(profile.profile!.stats.trips, 47);
  });
}
