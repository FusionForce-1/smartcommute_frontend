# Trip Planner & Fare Estimate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a logged-in commuter plan a trip from their GPS location to a stop or map-picked destination via `POST /trip-plan`, and view a fare breakdown of the option they choose.

**Architecture:** A `TripPlanService` (authenticated Dio) calls the existing backend endpoint; a `TripPlanProvider` (`ChangeNotifier`) owns location, destination, preference, results and error state; a dedicated `TripPlannerScreen`, a `PickDestinationScreen`, a stop search sheet and a `FareBreakdownSheet` render it. The commuter dashboard owns the provider so the Routes tab's "View fare estimate" tile can read the selected option.

**Tech Stack:** Flutter 3.44 / Dart (SDK `>=3.3.0`), `provider`, `dio`, `flutter_map`, `latlong2`, `geolocator`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-01-trip-planner-fare-estimate-design.md`

## Global Constraints

- Trust `POST /trip-plan` as-is. No client-side fare math.
- Origin is always the commuter's current GPS location. No manual origin.
- Destination: searchable stop list **and** "Pick on map".
- GeoJSON coordinates are sent as **[lng, lat]**.
- `TripPlanService` must use `buildDioClient()` (auth interceptor) in the app.
- Guests: Routes-tab tiles disabled with a sign-in banner.
- Fares formatted as `₱13.00`. Footer copy: `Estimated fare — actual fare may vary.`
- Error copy (exact):
  - 401/403 → `Sign in as a commuter to plan trips.`
  - connection error / timeout → `Can't reach the server. Check your connection.`
  - other → `Something went wrong. Please try again.`
  - location denied → `Location permission is needed to plan a trip.`
  - location services off → `Turn on location services to plan a trip.`
  - destination within 20 m of origin → `You're already there.`
- No new dependencies. Tests use `flutter_test` + an in-memory Dio `HttpClientAdapter`.
- **Do not commit during tasks.** The user will test-drive first; the single commit happens in Task 8 after their approval.
- Comments in new files follow the repo's style: short, may be Bisaya/English mix like existing files.

## Review Focus

1. Commuter changes destination or preference while a request is in flight → the old response is ignored; no stale results appear. (Task 3 test)
2. Commuter logs out / dashboard disposes while a request is in flight → no "used after dispose" crash. (Task 3 test)
3. Backend sends integer fares (`15` instead of `15.0`) → parsed as `double`, displayed `₱15.00`. (Task 1 test)
4. Stop search with mixed case, surrounding whitespace, or landmark text → matches; blank query → all stops. (Task 5 test)
5. Commuter's GPS origin is outside the Metro Cebu service area → "Pick on map" opens at the default Cebu center instead of tripping the camera constraint. (Task 5 test)

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/models/trip_plan.dart` (create) | `TripPreference`, `TripPlanResponse`, `RouteOption`, `RouteLeg`, `StopDisplay` extension, `formatFare`, `formatTransfers` |
| `lib/services/trip_plan_service.dart` (create) | `POST /trip-plan` |
| `lib/services/location_source.dart` (create) | `LocationSource` interface, `LocationException`, `GeolocatorLocationSource` |
| `lib/providers/trip_plan_provider.dart` (create) | Trip planning state + error mapping |
| `lib/widgets/fare_breakdown_sheet.dart` (create) | Fare breakdown bottom sheet |
| `lib/widgets/stop_search_sheet.dart` (create) | `filterStops` + stop search bottom sheet |
| `lib/config/map_config.dart` (create) | Shared service-area bounds, zoom limits, tile URL |
| `lib/screens/commuter/pick_destination_screen.dart` (create) | Full-screen crosshair map picker |
| `lib/screens/commuter/trip_planner_screen.dart` (create) | Planner UI |
| `lib/screens/commuter/commuter_dashboard.dart` (modify) | Own provider, wire Routes tiles, guest flag, use `MapConfig` |
| `test/support/fake_dio.dart` (create) | `FakeAdapter`, `jsonBody`, `fakeDio` |
| `test/support/trip_plan_fixtures.dart` (create) | Sample `/trip-plan` JSON |
| `test/support/fake_location_source.dart` (create) | `FakeLocationSource` |
| `test/models/trip_plan_test.dart`, `test/services/trip_plan_service_test.dart`, `test/providers/trip_plan_provider_test.dart`, `test/widgets/fare_breakdown_sheet_test.dart`, `test/widgets/stop_search_sheet_test.dart`, `test/screens/pick_destination_screen_test.dart`, `test/screens/trip_planner_screen_test.dart` (create) | Tests |

---

### Task 1: Trip plan model

**Files:**
- Create: `lib/models/trip_plan.dart`
- Create: `test/support/trip_plan_fixtures.dart`
- Test: `test/models/trip_plan_test.dart`

**Interfaces:**
- Consumes: `StopModel`, `GeoJSONPoint` from `lib/models/models.dart` (existing).
- Produces:
  - `enum TripPreference { time, fare, transfers }` with `String apiValue`, `String label`
  - `TripPlanResponse({required List<RouteOption> options, required DateTime generatedAt})`, `TripPlanResponse.fromJson(Map<String, dynamic>)`
  - `RouteOption({rank, legs, totalEtaMin, totalFare, transfers})`, `.fromJson`, `String get routeSummary`
  - `RouteLeg({routeId, routeName, boardStop, alightStop, etaMin, fare})`, `.fromJson`
  - `extension StopDisplay on StopModel { bool get isPlaceholder; String get displayName; }`
  - `String formatFare(double fare)`, `String formatTransfers(int transfers)`
  - Fixtures: `Map<String, dynamic> sampleResponse()`, `Map<String, dynamic> emptyResponse()`

- [ ] **Step 1: Create the fixtures**

`test/support/trip_plan_fixtures.dart`:
```dart
// Sample /trip-plan responses, same shape as backend trip_models.py.

Map<String, dynamic> stopJson(String id, String name, double lng, double lat) => {
      'id': id,
      'name': name,
      'sequence': 1,
      'location': {
        'type': 'Point',
        'coordinates': [lng, lat],
      },
      'route_ids': ['r1'],
      'landmark': null,
    };

/// Two legs, one transfer. First board stop is the backend stub's
/// placeholder ("0" at [0, 0]). Second leg fare is an int on purpose.
Map<String, dynamic> sampleResponse() => {
      'options': [
        {
          'rank': 1,
          'total_eta_min': 25,
          'total_fare': 28.0,
          'transfers': 1,
          'legs': [
            {
              'route_id': 'r1',
              'route_name': '01K',
              'board_stop': stopJson('0', 'Origin', 0, 0),
              'alight_stop': stopJson('s2', 'Colon', 123.9, 10.29),
              'eta_min': 10,
              'fare': 13.0,
            },
            {
              'route_id': 'r2',
              'route_name': '13C',
              'board_stop': stopJson('s2', 'Colon', 123.9, 10.29),
              'alight_stop': stopJson('s3', 'IT Park', 123.905, 10.33),
              'eta_min': 15,
              'fare': 15,
            },
          ],
        },
      ],
      'generated_at': '2026-10-01T08:00:00.123456',
    };

Map<String, dynamic> emptyResponse() => {
      'options': <dynamic>[],
      'generated_at': '2026-10-01T08:00:00',
    };
```

- [ ] **Step 2: Write the failing tests**

`test/models/trip_plan_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/models/trip_plan.dart';

import '../support/trip_plan_fixtures.dart';

void main() {
  group('TripPlanResponse.fromJson', () {
    test('parses options, legs and totals', () {
      final response = TripPlanResponse.fromJson(sampleResponse());

      final option = response.options.single;
      expect(option.rank, 1);
      expect(option.totalEtaMin, 25);
      expect(option.totalFare, 28.0);
      expect(option.transfers, 1);
      expect(option.legs, hasLength(2));
      expect(option.legs.first.routeName, '01K');
      expect(option.legs.first.alightStop.name, 'Colon');
      expect(option.routeSummary, '01K → 13C');
      expect(response.generatedAt.year, 2026);
    });

    test('accepts integer fares from the backend', () {
      final leg = TripPlanResponse.fromJson(sampleResponse()).options.single.legs[1];

      expect(leg.fare, isA<double>());
      expect(leg.fare, 15.0);
    });

    test('parses an empty options list', () {
      final response = TripPlanResponse.fromJson(emptyResponse());

      expect(response.options, isEmpty);
    });
  });

  group('StopDisplay', () {
    test('backend stub placeholder stop shows as "Your location"', () {
      final legs = TripPlanResponse.fromJson(sampleResponse()).options.single.legs;

      expect(legs.first.boardStop.isPlaceholder, isTrue);
      expect(legs.first.boardStop.displayName, 'Your location');
      expect(legs.first.alightStop.isPlaceholder, isFalse);
      expect(legs.first.alightStop.displayName, 'Colon');
    });
  });

  group('formatting', () {
    test('formatFare uses peso sign and two decimals', () {
      expect(formatFare(13), '₱13.00');
      expect(formatFare(27.5), '₱27.50');
    });

    test('formatTransfers pluralizes', () {
      expect(formatTransfers(0), 'No transfers');
      expect(formatTransfers(1), '1 transfer');
      expect(formatTransfers(2), '2 transfers');
    });

    test('TripPreference maps to backend minimize values', () {
      expect(TripPreference.time.apiValue, 'time');
      expect(TripPreference.fare.apiValue, 'fare');
      expect(TripPreference.transfers.apiValue, 'transfers');
      expect(TripPreference.time.label, 'Fastest');
    });
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/models/trip_plan_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:smartcommute_app/models/trip_plan.dart'`.

- [ ] **Step 4: Implement the model**

`lib/models/trip_plan.dart`:
```dart
// lib/models/trip_plan.dart
//
// Mirror sa backend trip_models.py (POST /trip-plan).
// Walay fare computation diri — gi-display ra nato unsa ang i-return sa backend.

import 'models.dart';

/// Unsa ang i-minimize sa trip planner (backend `preferences.minimize`).
enum TripPreference {
  time('time', 'Fastest'),
  fare('fare', 'Cheapest'),
  transfers('transfers', 'Fewest transfers');

  const TripPreference(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class TripPlanResponse {
  const TripPlanResponse({required this.options, required this.generatedAt});

  final List<RouteOption> options;
  final DateTime generatedAt;

  factory TripPlanResponse.fromJson(Map<String, dynamic> json) {
    return TripPlanResponse(
      options: (json['options'] as List<dynamic>)
          .map((option) => RouteOption.fromJson(option as Map<String, dynamic>))
          .toList(),
      generatedAt: DateTime.parse(json['generated_at'] as String),
    );
  }
}

class RouteOption {
  const RouteOption({
    required this.rank,
    required this.legs,
    required this.totalEtaMin,
    required this.totalFare,
    required this.transfers,
  });

  final int rank;
  final List<RouteLeg> legs;
  final int totalEtaMin;
  final double totalFare;
  final int transfers;

  /// E.g. "01K → 13C"
  String get routeSummary => legs.map((leg) => leg.routeName).join(' → ');

  factory RouteOption.fromJson(Map<String, dynamic> json) {
    return RouteOption(
      rank: json['rank'] as int,
      legs: (json['legs'] as List<dynamic>)
          .map((leg) => RouteLeg.fromJson(leg as Map<String, dynamic>))
          .toList(),
      totalEtaMin: json['total_eta_min'] as int,
      totalFare: (json['total_fare'] as num).toDouble(),
      transfers: json['transfers'] as int,
    );
  }
}

class RouteLeg {
  const RouteLeg({
    required this.routeId,
    required this.routeName,
    required this.boardStop,
    required this.alightStop,
    required this.etaMin,
    required this.fare,
  });

  final String routeId;
  final String routeName;
  final StopModel boardStop;
  final StopModel alightStop;
  final int etaMin;
  final double fare;

  factory RouteLeg.fromJson(Map<String, dynamic> json) {
    return RouteLeg(
      routeId: json['route_id'] as String,
      routeName: json['route_name'] as String,
      boardStop: StopModel.fromJson(json['board_stop'] as Map<String, dynamic>),
      alightStop: StopModel.fromJson(json['alight_stop'] as Map<String, dynamic>),
      etaMin: json['eta_min'] as int,
      fare: (json['fare'] as num).toDouble(),
    );
  }
}

extension StopDisplay on StopModel {
  /// Ang backend stub mo-return og "Origin" stop nga id "0" sa [0, 0]
  /// kung walay tinuod nga stop — ipakita nato as "Your location".
  bool get isPlaceholder => id == '0' || (location.lat == 0 && location.lng == 0);

  String get displayName => isPlaceholder ? 'Your location' : name;
}

String formatFare(double fare) => '₱${fare.toStringAsFixed(2)}';

String formatTransfers(int transfers) {
  if (transfers == 0) return 'No transfers';
  if (transfers == 1) return '1 transfer';
  return '$transfers transfers';
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/models/trip_plan_test.dart`
Expected: PASS (all 7 tests).

- [ ] **Step 6: Checkpoint (no commit)**

Run: `flutter analyze lib/models/trip_plan.dart test/models test/support`
Expected: `No issues found!`

---

### Task 2: Trip plan service

**Files:**
- Create: `lib/services/trip_plan_service.dart`
- Create: `test/support/fake_dio.dart`
- Test: `test/services/trip_plan_service_test.dart`

**Interfaces:**
- Consumes: `TripPlanResponse`, `TripPreference` (Task 1); fixtures (Task 1).
- Produces:
  - `TripPlanService(Dio dio)`
  - `Future<TripPlanResponse> planTrip({required LatLng origin, required LatLng destination, TripPreference preference = TripPreference.time})` — throws `DioException` on failure.
  - Test support: `FakeAdapter(FakeHandler handler)` with `List<RequestOptions> requests`; `ResponseBody jsonBody(Object body, {int status = 200})`; `Dio fakeDio(FakeAdapter adapter)`.

- [ ] **Step 1: Create the fake Dio support**

`test/support/fake_dio.dart`:
```dart
// In-memory Dio adapter para ma-test ang services nga walay tinuod nga server.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeHandler = Future<ResponseBody> Function(RequestOptions options);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final FakeHandler handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object body, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Dio fakeDio(FakeAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
}
```

- [ ] **Step 2: Write the failing tests**

`test/services/trip_plan_service_test.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/models/trip_plan.dart';
import 'package:smartcommute_app/services/trip_plan_service.dart';

import '../support/fake_dio.dart';
import '../support/trip_plan_fixtures.dart';

void main() {
  const origin = LatLng(10.31, 123.89);
  const destination = LatLng(10.33, 123.905);

  test('POSTs /trip-plan with GeoJSON [lng, lat] and minimize', () async {
    final adapter = FakeAdapter((_) async => jsonBody(sampleResponse()));
    final service = TripPlanService(fakeDio(adapter));

    final result = await service.planTrip(
      origin: origin,
      destination: destination,
      preference: TripPreference.fare,
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/trip-plan');
    final body = request.data as Map<String, dynamic>;
    expect(body['origin'], {
      'type': 'Point',
      'coordinates': [123.89, 10.31],
    });
    expect((body['destination'] as Map)['coordinates'], [123.905, 10.33]);
    expect(body['preferences'], {'minimize': 'fare', 'max_transfers': 2});
    expect(result.options.single.totalFare, 28.0);
  });

  test('defaults to minimize time', () async {
    final adapter = FakeAdapter((_) async => jsonBody(emptyResponse()));
    final service = TripPlanService(fakeDio(adapter));

    await service.planTrip(origin: origin, destination: destination);

    final body = adapter.requests.single.data as Map<String, dynamic>;
    expect((body['preferences'] as Map)['minimize'], 'time');
  });

  test('lets a 401 bubble up as DioException', () async {
    final adapter = FakeAdapter(
      (_) async => jsonBody({'detail': 'Not authenticated'}, status: 401),
    );
    final service = TripPlanService(fakeDio(adapter));

    await expectLater(
      service.planTrip(origin: origin, destination: destination),
      throwsA(isA<DioException>()),
    );
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/services/trip_plan_service_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:smartcommute_app/services/trip_plan_service.dart'`.

- [ ] **Step 4: Implement the service**

`lib/services/trip_plan_service.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../models/trip_plan.dart';

// Tawag sa backend POST /trip-plan (commuter only).
// I-pass ang Dio gikan sa buildDioClient() para ma-attach ang token.
class TripPlanService {
  TripPlanService(this._dio);

  final Dio _dio;

  Future<TripPlanResponse> planTrip({
    required LatLng origin,
    required LatLng destination,
    TripPreference preference = TripPreference.time,
  }) async {
    final response = await _dio.post('/trip-plan', data: {
      'origin': _point(origin),
      'destination': _point(destination),
      'preferences': {
        'minimize': preference.apiValue,
        'max_transfers': 2,
      },
    });

    return TripPlanResponse.fromJson(response.data as Map<String, dynamic>);
  }

  // GeoJSON order is [lng, lat] — dali ra mabali, double check
  static Map<String, dynamic> _point(LatLng point) => {
        'type': 'Point',
        'coordinates': [point.longitude, point.latitude],
      };
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/services/trip_plan_service_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Checkpoint (no commit)**

Run: `flutter analyze lib/services/trip_plan_service.dart test/services test/support`
Expected: `No issues found!`

---

### Task 3: Location source and trip plan provider

**Files:**
- Create: `lib/services/location_source.dart`
- Create: `lib/providers/trip_plan_provider.dart`
- Create: `test/support/fake_location_source.dart`
- Test: `test/providers/trip_plan_provider_test.dart`

**Interfaces:**
- Consumes: `TripPlanService.planTrip` (Task 2), `TripPreference`, `RouteOption` (Task 1), `FakeAdapter`/`jsonBody`/`fakeDio` (Task 2), fixtures (Task 1).
- Produces:
  - `enum LocationFailure { servicesOff, denied }`
  - `class LocationException implements Exception { const LocationException(LocationFailure reason); final LocationFailure reason; String get message; }`
  - `abstract class LocationSource { Future<LatLng> currentLocation(); Future<void> openSettings(); }`
  - `class GeolocatorLocationSource implements LocationSource`
  - `enum TripPlanStatus { idle, loading, success, empty, error }`
  - `TripPlanProvider({required TripPlanService service, required LocationSource locationSource})` with getters `origin`, `isLocating`, `locationError`, `destination`, `destinationLabel`, `preference`, `status`, `options`, `selectedOption`, `errorMessage`, `canPlan`; methods `locateOrigin()`, `openLocationSettings()`, `setDestination(LatLng, String)`, `setPreference(TripPreference)`, `plan()`, `selectOption(RouteOption)`.
  - Test support: `FakeLocationSource({LatLng? result, LocationFailure? failure})` with `int settingsOpened`.

Note: the spec lists `locating` as a `status` value. Location state is kept separate (`isLocating` / `locationError`) so a location failure and a planning failure can be shown in different places on screen. Behavior is unchanged.

- [ ] **Step 1: Create the location source (needed by the fake)**

`lib/services/location_source.dart`:
```dart
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationFailure { servicesOff, denied }

class LocationException implements Exception {
  const LocationException(this.reason);

  final LocationFailure reason;

  String get message => switch (reason) {
        LocationFailure.servicesOff => 'Turn on location services to plan a trip.',
        LocationFailure.denied => 'Location permission is needed to plan a trip.',
      };
}

/// Gi-abstract ang GPS para ma-test ang TripPlanProvider nga walay Geolocator.
abstract class LocationSource {
  Future<LatLng> currentLocation();
  Future<void> openSettings();
}

class GeolocatorLocationSource implements LocationSource {
  @override
  Future<LatLng> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationFailure.servicesOff);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationException(LocationFailure.denied);
    }

    final position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}
```

`test/support/fake_location_source.dart`:
```dart
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/services/location_source.dart';

class FakeLocationSource implements LocationSource {
  FakeLocationSource({this.result, this.failure});

  LatLng? result;
  LocationFailure? failure;
  int settingsOpened = 0;

  @override
  Future<LatLng> currentLocation() async {
    final failure = this.failure;
    if (failure != null) throw LocationException(failure);
    return result!;
  }

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }
}
```

- [ ] **Step 2: Write the failing provider tests**

`test/providers/trip_plan_provider_test.dart`:
```dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/models/trip_plan.dart';
import 'package:smartcommute_app/providers/trip_plan_provider.dart';
import 'package:smartcommute_app/services/location_source.dart';
import 'package:smartcommute_app/services/trip_plan_service.dart';

import '../support/fake_dio.dart';
import '../support/fake_location_source.dart';
import '../support/trip_plan_fixtures.dart';

const origin = LatLng(10.31, 123.89);
const destination = LatLng(10.33, 123.905);

TripPlanProvider buildProvider(FakeAdapter adapter, {FakeLocationSource? location}) {
  return TripPlanProvider(
    service: TripPlanService(fakeDio(adapter)),
    locationSource: location ?? FakeLocationSource(result: origin),
  );
}

FakeAdapter okAdapter() => FakeAdapter((_) async => jsonBody(sampleResponse()));

Future<TripPlanProvider> readyProvider(FakeAdapter adapter) async {
  final provider = buildProvider(adapter);
  await provider.locateOrigin();
  provider.setDestination(destination, 'IT Park');
  return provider;
}

void main() {
  group('locateOrigin', () {
    test('sets origin on success', () async {
      final provider = buildProvider(okAdapter());

      await provider.locateOrigin();

      expect(provider.origin, origin);
      expect(provider.locationError, isNull);
      expect(provider.isLocating, isFalse);
    });

    test('permission denied sets message and keeps planning disabled', () async {
      final provider = buildProvider(
        okAdapter(),
        location: FakeLocationSource(failure: LocationFailure.denied),
      );

      await provider.locateOrigin();
      provider.setDestination(destination, 'IT Park');

      expect(provider.origin, isNull);
      expect(provider.locationError, 'Location permission is needed to plan a trip.');
      expect(provider.canPlan, isFalse);
    });

    test('location services off sets message', () async {
      final provider = buildProvider(
        okAdapter(),
        location: FakeLocationSource(failure: LocationFailure.servicesOff),
      );

      await provider.locateOrigin();

      expect(provider.locationError, 'Turn on location services to plan a trip.');
    });

    test('openLocationSettings delegates to the location source', () async {
      final location = FakeLocationSource(result: origin);
      final provider = buildProvider(okAdapter(), location: location);

      await provider.openLocationSettings();

      expect(location.settingsOpened, 1);
    });
  });

  group('plan', () {
    test('does nothing without a destination', () async {
      final adapter = okAdapter();
      final provider = buildProvider(adapter);
      await provider.locateOrigin();

      await provider.plan();

      expect(adapter.requests, isEmpty);
      expect(provider.status, TripPlanStatus.idle);
    });

    test('success stores options and allows selecting one', () async {
      final provider = await readyProvider(okAdapter());

      await provider.plan();

      expect(provider.status, TripPlanStatus.success);
      expect(provider.options, hasLength(1));
      expect(provider.selectedOption, isNull);

      provider.selectOption(provider.options.single);
      expect(provider.selectedOption, same(provider.options.single));
    });

    test('sends the chosen preference', () async {
      final adapter = okAdapter();
      final provider = await readyProvider(adapter);

      provider.setPreference(TripPreference.fare);
      await provider.plan();

      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect((body['preferences'] as Map)['minimize'], 'fare');
    });

    test('empty options sets empty status', () async {
      final provider = await readyProvider(
        FakeAdapter((_) async => jsonBody(emptyResponse())),
      );

      await provider.plan();

      expect(provider.status, TripPlanStatus.empty);
      expect(provider.options, isEmpty);
    });

    test('401 maps to the sign-in message', () async {
      final provider = await readyProvider(
        FakeAdapter((_) async => jsonBody({'detail': 'no'}, status: 401)),
      );

      await provider.plan();

      expect(provider.status, TripPlanStatus.error);
      expect(provider.errorMessage, 'Sign in as a commuter to plan trips.');
    });

    test('403 maps to the sign-in message', () async {
      final provider = await readyProvider(
        FakeAdapter((_) async => jsonBody({'detail': 'no'}, status: 403)),
      );

      await provider.plan();

      expect(provider.errorMessage, 'Sign in as a commuter to plan trips.');
    });

    test('connection error maps to the offline message', () async {
      final provider = await readyProvider(
        FakeAdapter((options) async => throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            )),
      );

      await provider.plan();

      expect(provider.errorMessage, "Can't reach the server. Check your connection.");
    });

    test('500 maps to the generic message', () async {
      final provider = await readyProvider(
        FakeAdapter((_) async => jsonBody({'detail': 'boom'}, status: 500)),
      );

      await provider.plan();

      expect(provider.errorMessage, 'Something went wrong. Please try again.');
    });

    test('destination within 20 m is blocked without a request', () async {
      final adapter = okAdapter();
      final provider = buildProvider(adapter);
      await provider.locateOrigin();
      provider.setDestination(const LatLng(10.31004, 123.89), 'Right here');

      await provider.plan();

      expect(adapter.requests, isEmpty);
      expect(provider.status, TripPlanStatus.error);
      expect(provider.errorMessage, "You're already there.");
    });

    test('double tap sends only one request', () async {
      final gate = Completer<ResponseBody>();
      final adapter = FakeAdapter((_) => gate.future);
      final provider = await readyProvider(adapter);

      final first = provider.plan();
      final second = provider.plan();
      expect(provider.canPlan, isFalse);
      gate.complete(jsonBody(sampleResponse()));
      await Future.wait([first, second]);

      expect(adapter.requests, hasLength(1));
      expect(provider.status, TripPlanStatus.success);
    });

    test('changing destination mid-request ignores the stale response', () async {
      final gate = Completer<ResponseBody>();
      final provider = await readyProvider(FakeAdapter((_) => gate.future));

      final pending = provider.plan();
      provider.setDestination(const LatLng(10.29, 123.9), 'Colon');
      gate.complete(jsonBody(sampleResponse()));
      await pending;

      expect(provider.status, TripPlanStatus.idle);
      expect(provider.options, isEmpty);
      expect(provider.destinationLabel, 'Colon');
    });

    test('changing preference mid-request ignores the stale response', () async {
      final gate = Completer<ResponseBody>();
      final provider = await readyProvider(FakeAdapter((_) => gate.future));

      final pending = provider.plan();
      provider.setPreference(TripPreference.transfers);
      gate.complete(jsonBody(sampleResponse()));
      await pending;

      expect(provider.status, TripPlanStatus.idle);
      expect(provider.options, isEmpty);
    });

    test('new destination clears previous results and selection', () async {
      final provider = await readyProvider(okAdapter());
      await provider.plan();
      provider.selectOption(provider.options.single);

      provider.setDestination(const LatLng(10.29, 123.9), 'Colon');

      expect(provider.options, isEmpty);
      expect(provider.selectedOption, isNull);
      expect(provider.status, TripPlanStatus.idle);
    });

    test('disposing mid-request does not throw', () async {
      final gate = Completer<ResponseBody>();
      final provider = await readyProvider(FakeAdapter((_) => gate.future));

      final pending = provider.plan();
      provider.dispose();
      gate.complete(jsonBody(sampleResponse()));

      await expectLater(pending, completes);
    });
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/providers/trip_plan_provider_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:smartcommute_app/providers/trip_plan_provider.dart'`.

- [ ] **Step 4: Implement the provider**

`lib/providers/trip_plan_provider.dart`:
```dart
// lib/providers/trip_plan_provider.dart
//
// State sa Trip Planner: GPS origin, destination, preference, results.
// Gi-own sa CommuterDashboard para mabasa sa "View fare estimate" tile
// ang selectedOption bisan sirado na ang planner screen.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/trip_plan.dart';
import '../services/location_source.dart';
import '../services/trip_plan_service.dart';

enum TripPlanStatus { idle, loading, success, empty, error }

class TripPlanProvider extends ChangeNotifier {
  TripPlanProvider({
    required TripPlanService service,
    required LocationSource locationSource,
  })  : _service = service,
        _locationSource = locationSource;

  /// Kung ingon ani ka duol ang destination, naa na sila.
  static const double alreadyThereMeters = 20;

  static const String _genericError = 'Something went wrong. Please try again.';

  final TripPlanService _service;
  final LocationSource _locationSource;

  LatLng? _origin;
  bool _isLocating = false;
  String? _locationError;

  LatLng? _destination;
  String? _destinationLabel;
  TripPreference _preference = TripPreference.time;

  TripPlanStatus _status = TripPlanStatus.idle;
  List<RouteOption> _options = const [];
  RouteOption? _selectedOption;
  String? _errorMessage;

  // Mo-increment kada clear para ma-ignore ang daan nga response.
  int _requestId = 0;
  bool _disposed = false;

  LatLng? get origin => _origin;
  bool get isLocating => _isLocating;
  String? get locationError => _locationError;
  LatLng? get destination => _destination;
  String? get destinationLabel => _destinationLabel;
  TripPreference get preference => _preference;
  TripPlanStatus get status => _status;
  List<RouteOption> get options => _options;
  RouteOption? get selectedOption => _selectedOption;
  String? get errorMessage => _errorMessage;

  bool get canPlan =>
      _origin != null &&
      _destination != null &&
      !_isLocating &&
      _status != TripPlanStatus.loading;

  Future<void> locateOrigin() async {
    if (_isLocating) return;
    _isLocating = true;
    _locationError = null;
    _notify();

    try {
      _origin = await _locationSource.currentLocation();
    } on LocationException catch (e) {
      _origin = null;
      _locationError = e.message;
    } catch (_) {
      _origin = null;
      _locationError = 'Unable to get your current location.';
    }

    _isLocating = false;
    _notify();
  }

  Future<void> openLocationSettings() => _locationSource.openSettings();

  void setDestination(LatLng destination, String label) {
    _destination = destination;
    _destinationLabel = label;
    _clearResults();
    _notify();
  }

  void setPreference(TripPreference preference) {
    if (preference == _preference) return;
    _preference = preference;
    _clearResults();
    _notify();
  }

  Future<void> plan() async {
    if (!canPlan) return;
    final origin = _origin!;
    final destination = _destination!;

    _clearResults();
    if (const Distance().as(LengthUnit.Meter, origin, destination) <
        alreadyThereMeters) {
      _status = TripPlanStatus.error;
      _errorMessage = "You're already there.";
      _notify();
      return;
    }

    final requestId = _requestId;
    _status = TripPlanStatus.loading;
    _notify();

    try {
      final response = await _service.planTrip(
        origin: origin,
        destination: destination,
        preference: _preference,
      );
      if (requestId != _requestId) return;
      _options = response.options;
      _status = _options.isEmpty ? TripPlanStatus.empty : TripPlanStatus.success;
    } on DioException catch (e) {
      if (requestId != _requestId) return;
      _status = TripPlanStatus.error;
      _errorMessage = _messageFor(e);
    } catch (_) {
      if (requestId != _requestId) return;
      _status = TripPlanStatus.error;
      _errorMessage = _genericError;
    }
    _notify();
  }

  void selectOption(RouteOption option) {
    _selectedOption = option;
    _notify();
  }

  void _clearResults() {
    _requestId++;
    _status = TripPlanStatus.idle;
    _options = const [];
    _selectedOption = null;
    _errorMessage = null;
  }

  static String _messageFor(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) {
      return 'Sign in as a commuter to plan trips.';
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return "Can't reach the server. Check your connection.";
      default:
        return _genericError;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/providers/trip_plan_provider_test.dart`
Expected: PASS (18 tests).

- [ ] **Step 6: Checkpoint (no commit)**

Run: `flutter analyze lib/services lib/providers test/providers test/support`
Expected: `No issues found!`

---

### Task 4: Fare breakdown sheet

**Files:**
- Create: `lib/widgets/fare_breakdown_sheet.dart`
- Test: `test/widgets/fare_breakdown_sheet_test.dart`

**Interfaces:**
- Consumes: `RouteOption`, `RouteLeg`, `StopDisplay`, `formatFare`, `formatTransfers` (Task 1); `AppColors`, `AppSpacing`, `AppRadius` from `lib/config/theme_config.dart`; `AppIcons.vehicle` from `lib/constants/app_icons.dart`.
- Produces:
  - `class FareBreakdownSheet extends StatelessWidget { const FareBreakdownSheet({super.key, required RouteOption option}); }`
  - `Future<void> showFareBreakdownSheet(BuildContext context, RouteOption option)`

- [ ] **Step 1: Write the failing test**

`test/widgets/fare_breakdown_sheet_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/models/trip_plan.dart';
import 'package:smartcommute_app/widgets/fare_breakdown_sheet.dart';

import '../support/trip_plan_fixtures.dart';

void main() {
  testWidgets('shows total, one row per leg, and the estimate note', (tester) async {
    final option = TripPlanResponse.fromJson(sampleResponse()).options.single;

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: FareBreakdownSheet(option: option))),
    );

    expect(find.text('₱28.00'), findsOneWidget);
    expect(find.text('25 min · 1 transfer'), findsOneWidget);
    expect(find.text('01K'), findsOneWidget);
    expect(find.text('13C'), findsOneWidget);
    expect(find.text('Board at Your location → Alight at Colon'), findsOneWidget);
    expect(find.text('Board at Colon → Alight at IT Park'), findsOneWidget);
    expect(find.text('₱13.00'), findsOneWidget);
    expect(find.text('₱15.00'), findsOneWidget);
    expect(find.text('Estimated fare — actual fare may vary.'), findsOneWidget);
  });

  testWidgets('showFareBreakdownSheet opens it as a bottom sheet', (tester) async {
    final option = TripPlanResponse.fromJson(sampleResponse()).options.single;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFareBreakdownSheet(context, option),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(FareBreakdownSheet), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/fare_breakdown_sheet_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:smartcommute_app/widgets/fare_breakdown_sheet.dart'`.

- [ ] **Step 3: Implement the sheet**

`lib/widgets/fare_breakdown_sheet.dart`:
```dart
// lib/widgets/fare_breakdown_sheet.dart
//
// Fare breakdown sa gipili nga route option — total, ETA, transfers,
// ug fare kada leg. Numbers gikan tanan sa backend /trip-plan.

import 'package:flutter/material.dart';

import '../config/theme_config.dart';
import '../constants/app_icons.dart';
import '../models/trip_plan.dart';

Future<void> showFareBreakdownSheet(BuildContext context, RouteOption option) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (context) => SafeArea(child: FareBreakdownSheet(option: option)),
  );
}

class FareBreakdownSheet extends StatelessWidget {
  const FareBreakdownSheet({super.key, required this.option});

  final RouteOption option;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Fare estimate', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatFare(option.totalFare),
            style: textTheme.headlineMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${option.totalEtaMin} min · ${formatTransfers(option.transfers)}',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const Divider(height: AppSpacing.md),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: option.legs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) => _LegRow(leg: option.legs[index]),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Estimated fare — actual fare may vary.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _LegRow extends StatelessWidget {
  const _LegRow({required this.leg});

  final RouteLeg leg;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(AppIcons.vehicle, color: AppColors.secondary),
      title: Text(leg.routeName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Board at ${leg.boardStop.displayName} → Alight at ${leg.alightStop.displayName}',
          ),
          Text('${leg.etaMin} min'),
        ],
      ),
      trailing: Text(
        formatFare(leg.fare),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/fare_breakdown_sheet_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Checkpoint (no commit)**

Run: `flutter analyze lib/widgets/fare_breakdown_sheet.dart test/widgets`
Expected: `No issues found!`

---

### Task 5: Destination pickers (stop search + pick on map)

**Files:**
- Create: `lib/config/map_config.dart`
- Create: `lib/widgets/stop_search_sheet.dart`
- Create: `lib/screens/commuter/pick_destination_screen.dart`
- Test: `test/widgets/stop_search_sheet_test.dart`
- Test: `test/screens/pick_destination_screen_test.dart`

**Interfaces:**
- Consumes: `TransportStop` (`lib/models/transport_stop.dart`, existing: `id, name, location, routeIds, sequence, landmark`); `StopImage({required LatLng location, int size, BoxFit fit, double fallbackIconSize})` from `lib/widgets/stop_image.dart`; theme tokens.
- Produces:
  - `class MapConfig { static final LatLngBounds serviceArea; static const LatLng defaultCenter; static const double minZoom, maxZoom; static const String tileUrl, userAgentPackageName; }`
  - `List<TransportStop> filterStops(List<TransportStop> stops, String query)`
  - `Future<TransportStop?> showStopSearchSheet(BuildContext context, List<TransportStop> stops)`
  - `LatLng initialPickCenter(LatLng? origin)`
  - `class PickDestinationScreen extends StatefulWidget { const PickDestinationScreen({super.key, LatLng? origin}); }` — pops with the chosen `LatLng`.

- [ ] **Step 1: Write the failing tests**

`test/widgets/stop_search_sheet_test.dart`:
```dart
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
```

`test/screens/pick_destination_screen_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/config/map_config.dart';
import 'package:smartcommute_app/screens/commuter/pick_destination_screen.dart';

void main() {
  test('uses the origin when it is inside the service area', () {
    const inCebu = LatLng(10.31, 123.89);

    expect(initialPickCenter(inCebu), inCebu);
  });

  test('falls back to the default center when origin is outside Metro Cebu', () {
    const manila = LatLng(14.5995, 120.9842);

    expect(initialPickCenter(manila), MapConfig.defaultCenter);
  });

  test('falls back to the default center when there is no origin', () {
    expect(initialPickCenter(null), MapConfig.defaultCenter);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/stop_search_sheet_test.dart test/screens/pick_destination_screen_test.dart`
Expected: FAIL — missing `stop_search_sheet.dart`, `map_config.dart`, `pick_destination_screen.dart`.

- [ ] **Step 3: Implement `MapConfig`**

`lib/config/map_config.dart`:
```dart
// lib/config/map_config.dart
//
// Shared map settings para parehas ang Live Map ug Pick-on-map screen.

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapConfig {
  MapConfig._();

  // Service area sa app (Metro Cebu: Talisay, Cebu City, Mandaue, Lapu-Lapu, Consolacion).
  // Usba ni kung mo-expand ang coverage.
  static final LatLngBounds serviceArea = LatLngBounds(
    const LatLng(10.20, 123.80), // southwest
    const LatLng(10.45, 124.05), // northeast
  );
  static const LatLng defaultCenter = LatLng(10.3157, 123.8854);
  static const double minZoom = 12;
  static const double maxZoom = 18;
  static const String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String userAgentPackageName = 'com.smartcommute.app';
}
```

- [ ] **Step 4: Implement the stop search sheet**

`lib/widgets/stop_search_sheet.dart`:
```dart
// lib/widgets/stop_search_sheet.dart
//
// Searchable list sa stops para pilian sa commuter ang destination.

import 'package:flutter/material.dart';

import '../config/theme_config.dart';
import '../constants/app_icons.dart';
import '../models/transport_stop.dart';
import 'stop_image.dart';

/// Filter by name or landmark, case-insensitive. Blank query → tanan.
List<TransportStop> filterStops(List<TransportStop> stops, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return stops;
  return stops
      .where((stop) =>
          stop.name.toLowerCase().contains(q) ||
          (stop.landmark?.toLowerCase().contains(q) ?? false))
      .toList();
}

Future<TransportStop?> showStopSearchSheet(
  BuildContext context,
  List<TransportStop> stops,
) {
  return showModalBottomSheet<TransportStop>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => _StopSearchSheet(stops: stops),
  );
}

class _StopSearchSheet extends StatefulWidget {
  const _StopSearchSheet({required this.stops});

  final List<TransportStop> stops;

  @override
  State<_StopSearchSheet> createState() => _StopSearchSheetState();
}

class _StopSearchSheetState extends State<_StopSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = filterStops(widget.stops, _query);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.xs,
              ),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search stops or landmarks',
                  prefixIcon: Icon(AppIcons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          widget.stops.isEmpty
                              ? 'No stops available yet. Try "Pick on map".'
                              : 'No stops match "${_query.trim()}".',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final stop = results[index];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: StopImage(location: stop.location, size: 96),
                            ),
                          ),
                          title: Text(stop.name),
                          subtitle:
                              stop.landmark == null ? null : Text(stop.landmark!),
                          onTap: () => Navigator.of(context).pop(stop),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Implement the pick-on-map screen**

`lib/screens/commuter/pick_destination_screen.dart`:
```dart
// lib/screens/commuter/pick_destination_screen.dart
//
// I-drag ang map para ang pin sa tunga mao ang destination.
// Mo-pop og LatLng kung i-tap ang "Set destination".

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/map_config.dart';
import '../../config/theme_config.dart';

/// Sugod sa location sa commuter kung naa sa service area,
/// kung dili, sa default center (para dili ma-assert ang camera constraint).
LatLng initialPickCenter(LatLng? origin) {
  if (origin != null && MapConfig.serviceArea.contains(origin)) return origin;
  return MapConfig.defaultCenter;
}

class PickDestinationScreen extends StatefulWidget {
  const PickDestinationScreen({super.key, this.origin});

  final LatLng? origin;

  @override
  State<PickDestinationScreen> createState() => _PickDestinationScreenState();
}

class _PickDestinationScreenState extends State<PickDestinationScreen> {
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Pick destination'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialPickCenter(widget.origin),
              initialZoom: 15,
              minZoom: MapConfig.minZoom,
              maxZoom: MapConfig.maxZoom,
              cameraConstraint: CameraConstraint.contain(
                bounds: MapConfig.serviceArea,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrl,
                userAgentPackageName: MapConfig.userAgentPackageName,
              ),
            ],
          ),
          // Tip sa pin mao ang center sa map (icon gi-offset og tunga sa iyang height)
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 48),
                child: Icon(Icons.location_pin, size: 48, color: AppColors.error),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: SafeArea(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () =>
                    Navigator.of(context).pop(_mapController.camera.center),
                icon: const Icon(Icons.check),
                label: const Text('Set destination'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/widgets/stop_search_sheet_test.dart test/screens/pick_destination_screen_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 7: Checkpoint (no commit)**

Run: `flutter analyze lib/config/map_config.dart lib/widgets/stop_search_sheet.dart lib/screens/commuter/pick_destination_screen.dart test/widgets test/screens`
Expected: `No issues found!`

---

### Task 6: Trip planner screen

**Files:**
- Create: `lib/screens/commuter/trip_planner_screen.dart`
- Test: `test/screens/trip_planner_screen_test.dart`

**Interfaces:**
- Consumes: `TripPlanProvider`, `TripPlanStatus` (Task 3); `TripPreference`, `RouteOption`, `formatFare`, `formatTransfers` (Task 1); `showFareBreakdownSheet` (Task 4); `showStopSearchSheet`, `PickDestinationScreen` (Task 5); `TransportStop`; theme tokens and `AppIcons` (`myLocation`, `location`, `search`, `settings`, `errorRetry`, `emptyState`).
- Produces: `class TripPlannerScreen extends StatefulWidget { const TripPlannerScreen({super.key, required List<TransportStop> stops}); }` — expects a `TripPlanProvider` above it in the tree.

- [ ] **Step 1: Write the failing test**

`test/screens/trip_planner_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:smartcommute_app/providers/trip_plan_provider.dart';
import 'package:smartcommute_app/screens/commuter/trip_planner_screen.dart';
import 'package:smartcommute_app/services/location_source.dart';
import 'package:smartcommute_app/services/trip_plan_service.dart';
import 'package:smartcommute_app/widgets/fare_breakdown_sheet.dart';

import '../support/fake_dio.dart';
import '../support/fake_location_source.dart';
import '../support/trip_plan_fixtures.dart';

// FilledButton.icon may be a private subclass, so match by base type.
Finder findRoutesButton() => find.ancestor(
      of: find.text('Find routes'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );

bool isEnabled(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(findRoutesButton()).onPressed != null;

Future<TripPlanProvider> pumpPlanner(
  WidgetTester tester, {
  FakeLocationSource? location,
}) async {
  final provider = TripPlanProvider(
    service: TripPlanService(
      fakeDio(FakeAdapter((_) async => jsonBody(sampleResponse()))),
    ),
    locationSource: location ?? FakeLocationSource(result: const LatLng(10.31, 123.89)),
  );
  await tester.pumpWidget(MaterialApp(
    home: ChangeNotifierProvider<TripPlanProvider>.value(
      value: provider,
      child: const TripPlannerScreen(stops: []),
    ),
  ));
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  testWidgets('locates origin on open and plans a trip end to end', (tester) async {
    final provider = await pumpPlanner(tester);

    expect(find.text('10.3100, 123.8900'), findsOneWidget);
    expect(isEnabled(tester), isFalse);

    provider.setDestination(const LatLng(10.33, 123.905), 'IT Park');
    await tester.pump();
    expect(find.text('To: IT Park'), findsOneWidget);

    expect(isEnabled(tester), isTrue);
    await tester.tap(findRoutesButton());
    await tester.pumpAndSettle();
    expect(find.text('01K → 13C'), findsOneWidget);
    expect(find.text('₱28.00'), findsOneWidget);

    await tester.tap(find.text('01K → 13C'));
    await tester.pumpAndSettle();
    expect(find.byType(FareBreakdownSheet), findsOneWidget);
    expect(provider.selectedOption, isNotNull);
  });

  testWidgets('shows the location error and keeps Find routes disabled', (tester) async {
    final provider = await pumpPlanner(
      tester,
      location: FakeLocationSource(failure: LocationFailure.denied),
    );
    provider.setDestination(const LatLng(10.33, 123.905), 'IT Park');
    await tester.pump();

    expect(find.text('Location permission is needed to plan a trip.'), findsOneWidget);
    expect(isEnabled(tester), isFalse);
  });

  testWidgets('empty stop list shows a helpful message in the search sheet', (tester) async {
    await pumpPlanner(tester);

    await tester.tap(find.text('To: Choose a destination'));
    await tester.pumpAndSettle();

    expect(find.text('No stops available yet. Try "Pick on map".'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/trip_planner_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:smartcommute_app/screens/commuter/trip_planner_screen.dart'`.

- [ ] **Step 3: Implement the screen**

`lib/screens/commuter/trip_planner_screen.dart`:
```dart
// lib/screens/commuter/trip_planner_screen.dart
//
// Trip Planner: From = GPS location sa commuter, To = stop o pin sa map.
// Results gikan sa backend POST /trip-plan; i-tap ang option para sa fare breakdown.

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../models/transport_stop.dart';
import '../../models/trip_plan.dart';
import '../../providers/trip_plan_provider.dart';
import '../../widgets/fare_breakdown_sheet.dart';
import '../../widgets/stop_search_sheet.dart';
import 'pick_destination_screen.dart';

class TripPlannerScreen extends StatefulWidget {
  const TripPlannerScreen({super.key, required this.stops});

  /// Stops gikan sa /stops (gi-load na sa dashboard).
  final List<TransportStop> stops;

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  @override
  void initState() {
    super.initState();
    // I-refresh ang GPS kada abli sa planner
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TripPlanProvider>().locateOrigin();
    });
  }

  Future<void> _chooseStop() async {
    final stop = await showStopSearchSheet(context, widget.stops);
    if (stop == null || !mounted) return;
    context.read<TripPlanProvider>().setDestination(stop.location, stop.name);
  }

  Future<void> _pickOnMap() async {
    final trip = context.read<TripPlanProvider>();
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => PickDestinationScreen(origin: trip.origin),
      ),
    );
    if (picked == null || !mounted) return;
    trip.setDestination(
      picked,
      'Dropped pin (${picked.latitude.toStringAsFixed(4)}, '
      '${picked.longitude.toStringAsFixed(4)})',
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripPlanProvider>();
    final isLoading = trip.status == TripPlanStatus.loading;

    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Plan a trip'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _OriginCard(trip: trip),
          const SizedBox(height: AppSpacing.xs),
          _DestinationCard(
            label: trip.destinationLabel,
            onSearch: _chooseStop,
            onPickOnMap: _pickOnMap,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final preference in TripPreference.values)
                ChoiceChip(
                  label: Text(preference.label),
                  selected: trip.preference == preference,
                  onSelected: (_) => trip.setPreference(preference),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: trip.canPlan ? trip.plan : null,
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(AppIcons.search),
            label: const Text('Find routes'),
          ),
          const SizedBox(height: AppSpacing.md),
          _Results(trip: trip),
        ],
      ),
    );
  }
}

class _OriginCard extends StatelessWidget {
  const _OriginCard({required this.trip});

  final TripPlanProvider trip;

  @override
  Widget build(BuildContext context) {
    final origin = trip.origin;
    final error = trip.locationError;

    final String subtitle;
    if (trip.isLocating) {
      subtitle = 'Finding your location…';
    } else if (error != null) {
      subtitle = error;
    } else if (origin == null) {
      subtitle = 'Location not set';
    } else {
      subtitle = '${origin.latitude.toStringAsFixed(4)}, '
          '${origin.longitude.toStringAsFixed(4)}';
    }

    return _PlannerCard(
      child: ListTile(
        leading: const Icon(AppIcons.myLocation, color: AppColors.secondary),
        title: const Text('From: My location'),
        subtitle: Text(
          subtitle,
          style: error != null ? const TextStyle(color: AppColors.error) : null,
        ),
        trailing: trip.isLocating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null)
                    IconButton(
                      tooltip: 'Open settings',
                      icon: const Icon(AppIcons.settings),
                      onPressed: trip.openLocationSettings,
                    ),
                  IconButton(
                    tooltip: 'Refresh location',
                    icon: const Icon(AppIcons.errorRetry),
                    onPressed: trip.locateOrigin,
                  ),
                ],
              ),
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.label,
    required this.onSearch,
    required this.onPickOnMap,
  });

  final String? label;
  final VoidCallback onSearch;
  final VoidCallback onPickOnMap;

  @override
  Widget build(BuildContext context) {
    return _PlannerCard(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(AppIcons.location, color: AppColors.error),
            title: Text(label == null ? 'To: Choose a destination' : 'To: $label'),
            trailing: const Icon(AppIcons.search),
            onTap: onSearch,
          ),
          const Divider(height: 1),
          TextButton.icon(
            onPressed: onPickOnMap,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Pick on map'),
          ),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.trip});

  final TripPlanProvider trip;

  @override
  Widget build(BuildContext context) {
    return switch (trip.status) {
      TripPlanStatus.idle => const _Message(
          icon: AppIcons.search,
          text: 'Choose a destination, then tap Find routes.',
        ),
      TripPlanStatus.loading => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Center(child: CircularProgressIndicator()),
        ),
      TripPlanStatus.empty => const _Message(
          icon: AppIcons.emptyState,
          text: 'No route found to this destination.',
        ),
      TripPlanStatus.error => _Message(
          icon: AppIcons.errorRetry,
          text: trip.errorMessage ?? 'Something went wrong. Please try again.',
          color: AppColors.error,
        ),
      TripPlanStatus.success => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Route options', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            for (final option in trip.options)
              _OptionCard(
                option: option,
                selected: identical(trip.selectedOption, option),
                onTap: () {
                  trip.selectOption(option);
                  showFareBreakdownSheet(context, option);
                },
              ),
          ],
        ),
    };
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final RouteOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color: selected
              ? AppColors.primary
              : AppColors.secondary.withValues(alpha: 0.2),
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: Text('${option.rank}'),
        ),
        title: Text(option.routeSummary),
        subtitle: Text(
          '${option.totalEtaMin} min · ${formatTransfers(option.transfers)}',
        ),
        trailing: Text(
          formatFare(option.totalFare),
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Icon(icon, color: tint, size: 36),
          const SizedBox(height: AppSpacing.xs),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: tint)),
        ],
      ),
    );
  }
}

class _PlannerCard extends StatelessWidget {
  const _PlannerCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/trip_planner_screen_test.dart`
Expected: PASS (3 tests).
If `pumpAndSettle` times out after tapping Find routes (Dio not resolving inside the fake-async zone), wrap that tap in `await tester.runAsync(() async { await tester.tap(findRoutesButton()); await Future<void>.delayed(const Duration(milliseconds: 50)); });` followed by `await tester.pumpAndSettle();`.

- [ ] **Step 5: Checkpoint (no commit)**

Run: `flutter analyze lib/screens/commuter/trip_planner_screen.dart test/screens`
Expected: `No issues found!`

---

### Task 7: Wire the dashboard

**Files:**
- Modify: `lib/screens/commuter/commuter_dashboard.dart` (imports; `_CommuterDashboardState` lines ~38–110; `isGuest:` line ~94; `_serviceArea`/`_minZoom`/`_maxZoom` lines ~143–150; Routes and Profile action tiles lines ~514–555)

**Interfaces:**
- Consumes: `TripPlanProvider` (Task 3), `TripPlanService` (Task 2), `GeolocatorLocationSource` (Task 3), `buildDioClient()` from `lib/services/dio_interceptor.dart` (existing), `TripPlannerScreen` (Task 6), `showFareBreakdownSheet` (Task 4), `MapConfig` (Task 5).
- Produces: working Routes-tab tiles. No new public API.

- [ ] **Step 1: Add imports**

In `lib/screens/commuter/commuter_dashboard.dart`, after `import '../../widgets/stop_image.dart';` add:
```dart
import '../../config/map_config.dart';
import '../../providers/trip_plan_provider.dart';
import '../../services/dio_interceptor.dart';
import '../../services/location_source.dart';
import '../../services/trip_plan_service.dart';
import '../../widgets/fare_breakdown_sheet.dart';
import 'trip_planner_screen.dart';
```

- [ ] **Step 2: Own the provider in `_CommuterDashboardState`**

Add below `int _currentIndex = 0;`:
```dart
  // Trip planner state — naa diri para ma-share sa Routes tab ug planner screen.
  late final TripPlanProvider _tripPlanProvider = TripPlanProvider(
    service: TripPlanService(buildDioClient()),
    locationSource: GeolocatorLocationSource(),
  );

  @override
  void dispose() {
    _tripPlanProvider.dispose();
    super.dispose();
  }
```

In `build`, change `return Scaffold(` to wrap it:
```dart
    return ChangeNotifierProvider<TripPlanProvider>.value(
      value: _tripPlanProvider,
      child: Scaffold(
```
and close the extra paren after the Scaffold's closing `)`: the end of `build` becomes
```dart
      ),
    );
  }
```
(i.e. `Scaffold(...)` then `,` + `)` for the provider, then `;`).

- [ ] **Step 3: Pass the guest flag to every tab**

Change:
```dart
            isGuest: widget.isGuest && index == 3,
```
to:
```dart
            isGuest: widget.isGuest,
```
(The Profile tab already checks `widget.tab.label == 'Profile'` before showing its banner, so this only adds guest handling to Routes.)

- [ ] **Step 4: Use `MapConfig` for the shared map constants**

Replace:
```dart
    // Service area sa app (Metro Cebu: Talisay, Cebu City, Mandaue, Lapu-Lapu, Consolacion).
    // Usba ni kung mo-expand ang coverage.
    static final LatLngBounds _serviceArea = LatLngBounds(
      const LatLng(10.20, 123.80), // southwest
      const LatLng(10.45, 124.05), // northeast
    );
    static const double _minZoom = 12;
    static const double _maxZoom = 18;
```
with:
```dart
    // Gi-share sa Pick-on-map screen — usba sa lib/config/map_config.dart
    static final LatLngBounds _serviceArea = MapConfig.serviceArea;
    static const double _minZoom = MapConfig.minZoom;
    static const double _maxZoom = MapConfig.maxZoom;
```

- [ ] **Step 5: Add the navigation helpers to `_CommuterTabPlaceholderState`**

Add above `@override Widget build(BuildContext context)` of `_CommuterTabPlaceholderState`:
```dart
    // Ang pushed route wala sa ilalom sa dashboard, so i-pass balik ang provider.
    void _openTripPlanner(BuildContext context) {
      final trip = context.read<TripPlanProvider>();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider<TripPlanProvider>.value(
            value: trip,
            child: TripPlannerScreen(stops: _stops),
          ),
        ),
      );
    }

    void _openFareEstimate(BuildContext context) {
      final option = context.read<TripPlanProvider>().selectedOption;
      if (option == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Plan a trip first.'),
            action: SnackBarAction(
              label: 'Plan',
              onPressed: () => _openTripPlanner(context),
            ),
          ),
        );
        return;
      }
      showFareBreakdownSheet(context, option);
    }
```

- [ ] **Step 6: Replace the Routes tiles and share the guest banner**

Replace the whole `if (widget.tab.label == 'Routes') ...[ ... ],` block with:
```dart
          if (widget.tab.label == 'Routes') ...[
            if (widget.isGuest)
              const _GuestNotice(
                'Guest mode — sign in to plan trips and view fare estimates.',
              ),
            _PreviewActionTile(
              icon: AppIcons.search,
              label: 'Plan a trip',
              enabled: !widget.isGuest,
              onTap: () => _openTripPlanner(context),
            ),
            _PreviewActionTile(
              icon: AppIcons.fare,
              label: 'View fare estimate',
              enabled: !widget.isGuest,
              onTap: () => _openFareEstimate(context),
            ),
          ],
```

In the Profile block, replace the inline guest `Container(...)` (the one with text `'Guest mode — sign in to access profile and saved trips.'`) with:
```dart
            if (widget.isGuest)
              const _GuestNotice(
                'Guest mode — sign in to access profile and saved trips.',
              ),
```

Add this class just above `class _PreviewActionTile`:
```dart
class _GuestNotice extends StatelessWidget {
  const _GuestNotice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.error, fontSize: 13),
      ),
    );
  }
}
```

- [ ] **Step 7: Verify**

Run: `flutter analyze`
Expected: no errors (the pre-existing `_vehicleId` unused warning and TODO infos may remain).

Run: `flutter test`
Expected: all tests PASS (7 + 3 + 18 + 2 + 7 + 3 = 40).

- [ ] **Step 8: Checkpoint (no commit)** — hand over to the user for the test drive.

---

### Task 8: Test drive, then commit

**Files:** none changed unless the test drive finds bugs.

- [ ] **Step 1: Start the backend and app**

Backend (in `F:/Capstone Project/Smart-Commute-Backend`): run it the way the team normally does so it serves `API_BASE_URL` from the frontend `.env`.
Frontend: `flutter run` (choose the device you normally test on).

- [ ] **Step 2: User test-drive checklist**

Log in as a **commuter**, open the **Routes** tab:
1. Tap **View fare estimate** before planning → snackbar "Plan a trip first." with a **Plan** action that opens the planner.
2. Tap **Plan a trip** → "From: My location" shows a spinner, then coordinates. (Deny permission once to see the error + settings button; Retry recovers.)
3. Tap **To** → stop search opens with photos; typing filters by name and landmark; pick a stop → "To: <stop name>".
4. Tap **Pick on map** → map opens near you (or Cebu center); drag; **Set destination** → "To: Dropped pin (…)".
5. Switch **Fastest / Cheapest / Fewest transfers** → any previous results clear.
6. Tap **Find routes** → option card(s) with route names, ₱ fare, ETA, transfers. (Stub backend: ₱13.00 / 5 min — expected.)
7. Tap an option → fare breakdown sheet with total, per-leg rows, and the estimate note.
8. Close the planner → **View fare estimate** on the Routes tab now opens that same breakdown.
9. Stop the backend and tap **Find routes** → "Can't reach the server. Check your connection."
10. Log out, **Continue as Guest** → Routes tiles disabled with the guest banner.

- [ ] **Step 3: Fix anything found**, re-running `flutter test` and `flutter analyze` after each fix.

- [ ] **Step 4: Commit after the user approves**

```bash
git add lib/models/trip_plan.dart lib/services/trip_plan_service.dart lib/services/location_source.dart lib/providers/trip_plan_provider.dart lib/widgets/fare_breakdown_sheet.dart lib/widgets/stop_search_sheet.dart lib/config/map_config.dart lib/screens/commuter/pick_destination_screen.dart lib/screens/commuter/trip_planner_screen.dart lib/screens/commuter/commuter_dashboard.dart test/support test/models test/services test/providers test/widgets test/screens docs/superpowers
git commit -m "$(cat <<'EOF'
Add commuter trip planner and fare breakdown

Plan a trip from GPS location to a stop or map pin via POST /trip-plan,
and view the fare breakdown of the chosen option from the Routes tab.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```
