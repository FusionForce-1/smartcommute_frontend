# Operator Dashboard Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static operator dashboard with a responsive, read-only four-tab console (Dashboard, Vehicles, Routes, Live Monitoring) backed by `GET /fleet` and `GET /routes`.

**Architecture:** `OperatorService(Dio)` fetches data; one `OperatorProvider` (ChangeNotifier) owns fleet/routes state, derived counts and polling; `OperatorDashboard` owns the provider, picks a layout by width, and renders one tab widget at a time. Small shared widgets live in `lib/widgets/operator/`.

**Tech Stack:** Flutter (Material 3), `provider`, `dio`, `flutter_map` + `latlong2`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-05-operator-dashboard-design.md`

## Global Constraints

- No new dependencies in `pubspec.yaml` (no chart libs, no `fake_async`, no `intl`).
- Colours/radii/spacing/shadows only from `lib/config/theme_config.dart` (`AppColors`, `AppRadius`, `AppSpacing`, `AppShadows`); no hard-coded hex in operator files.
- Icons from `lib/constants/app_icons.dart` where one exists; otherwise `Icons.*`.
- Read-only: no create/edit/delete UI.
- Breakpoints: wide ≥ 1100 px, medium 700–1099 px, compact < 700 px. Live Monitoring side list at ≥ 900 px.
- Poll interval 15 s, only while Live Monitoring is shown.
- Error copy (exact): connection/timeout → `Can't reach the server. Check your connection.`; other → `Couldn't load fleet data. Try again.`
- `ApiService` is not modified. Services take a `Dio` (pattern of `TripPlanService`).
- Tests reuse `test/support/fake_dio.dart` (`FakeAdapter`, `jsonBody`, `fakeDio`). Widget tests that need `AuthProvider` build it as `AuthProvider(apiService: ApiService(dio: fakeDio(...)))` so `buildDioClient()`/dotenv is never touched.
- Baseline: `flutter test` = 49 pass, 1 pre-existing failure (`test/widget_test.dart`, "Missing definition of `main`"). Leave it alone; no new failures allowed.
- Commits: stage only the files listed in the task (the working tree has unrelated uncommitted work).

## Review Focus

1. **Empty fleet (0 vehicles)** — Fleet status bar must not divide by zero; Dashboard shows `No vehicles registered yet.` → test in Task 5.
2. **Provider disposed while a request is in flight** (operator switches screens / signs out mid-load) — no `notifyListeners` after dispose, no exception → test in Task 3.
3. **Overlapping polls** (slow server, tick fires during a refresh) — tick is skipped, only one request in flight → test in Task 3.
4. **Vehicle on a route not in `/routes`** — shown with the raw `routeId`, not a crash or blank → test in Task 3 (`routeName`) and Task 6.
5. **Phone width (360 px) with long plate/route names** — no RenderFlex overflow on any tab → test in Tasks 5–8 (`tester.takeException()` is null at 360 px with long-name fixtures).

---

### Task 1: Vehicle status grouping

**Files:**
- Create: `lib/models/vehicle_status.dart`
- Test: `test/models/vehicle_status_test.dart`

**Interfaces:**
- Produces: `enum VehicleStatusGroup { active, idle, offline }` with `static VehicleStatusGroup fromRaw(String raw)` and `String get label` (`'Active'`, `'Idle'`, `'Offline'`).

- [ ] **Step 1: Write the failing tests**

```dart
test('maps active synonyms', () {
  for (final s in ['active', 'in_service', 'on_route', 'moving']) {
    expect(VehicleStatusGroup.fromRaw(s), VehicleStatusGroup.active);
  }
});
test('maps idle synonyms', () {
  for (final s in ['idle', 'parked', 'standby']) {
    expect(VehicleStatusGroup.fromRaw(s), VehicleStatusGroup.idle);
  }
});
test('is case- and whitespace-insensitive', () {
  expect(VehicleStatusGroup.fromRaw('  ACTIVE '), VehicleStatusGroup.active);
});
test('unknown, empty and offline values map to offline', () {
  for (final s in ['offline', 'signal_lost', 'inactive', '', 'weird']) {
    expect(VehicleStatusGroup.fromRaw(s), VehicleStatusGroup.offline);
  }
});
test('labels', () {
  expect(VehicleStatusGroup.values.map((g) => g.label), ['Active', 'Idle', 'Offline']);
});
```

- [ ] **Step 2: Run to verify it fails** — `flutter test test/models/vehicle_status_test.dart` → FAIL (file/enum not found).
- [ ] **Step 3: Implement** `VehicleStatusGroup` in `lib/models/vehicle_status.dart` (normalise with `trim().toLowerCase()`, match against const sets).
- [ ] **Step 4: Run to verify it passes** — same command → all PASS.
- [ ] **Step 5: Commit** — `git add lib/models/vehicle_status.dart test/models/vehicle_status_test.dart && git commit -m "feat(operator): add vehicle status grouping"`

---

### Task 2: OperatorService + test fixtures

**Files:**
- Create: `lib/services/operator_service.dart`
- Create: `test/support/operator_fixtures.dart`
- Test: `test/services/operator_service_test.dart`

**Interfaces:**
- Consumes: `VehicleModel.fromJson`, `RouteModel.fromJson` (`lib/models/models.dart`).
- Produces:
  - `class OperatorService { OperatorService(Dio dio); Future<List<VehicleModel>> getFleet({String? operatorId}); Future<List<RouteModel>> getRoutes(); }` — `GET /fleet` with query `operator_id` only when non-null; `GET /routes`.
  - Fixtures in `test/support/operator_fixtures.dart`:
    - `Map<String, dynamic> vehicleJson({String id = 'v1', String plate = 'ABC-123', String routeId = 'r1', String status = 'active', String? crowd, double? lat, double? lng})` — `last_position` is `{'vehicle_id': id, 'lat': lat, 'lng': lng}` only when both lat/lng are non-null.
    - `Map<String, dynamic> routeJson({String id = 'r1', String code = '01K', String name = 'Urgello – Parkmall', bool isActive = true, int stopCount = 2})` — stops are `{'id','name': 'Stop $i','sequence': i,'location': {'type':'Point','coordinates':[123.89, 10.31]}}`, `fare_matrix: {'base': 13, 'per_km': 1.8}`.
    - `FakeAdapter operatorAdapter({List<Map<String, dynamic>> fleet = const [], List<Map<String, dynamic>> routes = const [], int fleetStatus = 200, Duration delay = Duration.zero})` — routes requests by `options.path` (`/fleet`, `/routes`); non-200 `fleetStatus` returns `jsonBody({'detail': 'boom'}, status: fleetStatus)`.

- [ ] **Step 1: Write the failing tests**

```dart
test('getFleet parses vehicles and sends operator_id', () async {
  final adapter = operatorAdapter(fleet: [vehicleJson(lat: 10.3, lng: 123.9)]);
  final fleet = await OperatorService(fakeDio(adapter)).getFleet(operatorId: 'op1');
  expect(fleet.single.plateNumber, 'ABC-123');
  expect(fleet.single.lastPosition!.lat, 10.3);
  expect(adapter.requests.single.queryParameters, {'operator_id': 'op1'});
});
test('getFleet omits operator_id when null', () async {
  final adapter = operatorAdapter();
  await OperatorService(fakeDio(adapter)).getFleet();
  expect(adapter.requests.single.queryParameters, isEmpty);
});
test('getRoutes parses routes with stops', () async {
  final routes = await OperatorService(fakeDio(operatorAdapter(routes: [routeJson(stopCount: 3)]))).getRoutes();
  expect(routes.single.code, '01K');
  expect(routes.single.stops, hasLength(3));
});
test('getFleet throws DioException on 500', () async {
  final svc = OperatorService(fakeDio(operatorAdapter(fleetStatus: 500)));
  expect(svc.getFleet(), throwsA(isA<DioException>()));
});
```

- [ ] **Step 2: Run to verify it fails** — `flutter test test/services/operator_service_test.dart` → FAIL (missing imports).
- [ ] **Step 3: Implement** `OperatorService` and the fixtures file.
- [ ] **Step 4: Run to verify it passes** — same command → PASS.
- [ ] **Step 5: Commit** — `git add lib/services/operator_service.dart test/support/operator_fixtures.dart test/services/operator_service_test.dart && git commit -m "feat(operator): add OperatorService for fleet and routes"`

---

### Task 3: OperatorProvider

**Files:**
- Create: `lib/providers/operator_provider.dart`
- Test: `test/providers/operator_provider_test.dart`

**Interfaces:**
- Consumes: `OperatorService` (Task 2), `VehicleStatusGroup` (Task 1).
- Produces `class OperatorProvider extends ChangeNotifier`:
  - `OperatorProvider({required OperatorService service, String? operatorId})`
  - `static const Duration pollInterval = Duration(seconds: 15);`
  - Getters: `List<VehicleModel> vehicles`, `List<RouteModel> routes` (unmodifiable), `bool isLoading`, `bool isRefreshing`, `String? error`, `DateTime? lastUpdated`, `bool hasData` (= `lastUpdated != null`), `bool isPolling`, `int totalVehicles`, `List<RouteModel> activeRoutes`, `Map<String, int> vehiclesByRoute`.
  - `int countFor(VehicleStatusGroup group)`
  - `String routeName(String routeId)` → `'${route.code} · ${route.name}'`, or `routeId` if unknown.
  - `Future<void> load()` — sets `isLoading` (true → false), fetches fleet + routes with `Future.wait`, clears `error` on success, sets `lastUpdated = DateTime.now()`.
  - `Future<bool> refresh()` — same fetch with `isRefreshing`; returns `false` on failure and keeps previous `vehicles`/`routes`/`lastUpdated`; returns `true` immediately-skipped `false`… **no**: if a load/refresh is already in flight, returns `false` without a new request.
  - `void startPolling([Duration interval = pollInterval])` (idempotent), `void stopPolling()`.
  - Error mapping: `DioException` of type `connectionTimeout`, `receiveTimeout`, `sendTimeout`, `connectionError` → `Can't reach the server. Check your connection.`; anything else → `Couldn't load fleet data. Try again.`
  - `dispose()` stops polling; after dispose, completing requests must not call `notifyListeners` (guard with a `_disposed` flag).

- [ ] **Step 1: Write the failing tests**

```dart
OperatorProvider build(FakeAdapter a) => OperatorProvider(service: OperatorService(fakeDio(a)));

test('load populates data and derived counts', () async {
  final p = build(operatorAdapter(
    fleet: [vehicleJson(id: 'a', status: 'active'), vehicleJson(id: 'b', status: 'idle'),
            vehicleJson(id: 'c', status: 'signal_lost', routeId: 'r2')],
    routes: [routeJson(), routeJson(id: 'r2', code: '04L', name: 'Lahug', isActive: false)],
  ));
  await p.load();
  expect(p.isLoading, isFalse);
  expect(p.error, isNull);
  expect(p.hasData, isTrue);
  expect(p.totalVehicles, 3);
  expect(p.countFor(VehicleStatusGroup.active), 1);
  expect(p.countFor(VehicleStatusGroup.idle), 1);
  expect(p.countFor(VehicleStatusGroup.offline), 1);
  expect(p.activeRoutes.map((r) => r.id), ['r1']);
  expect(p.vehiclesByRoute, {'r1': 2, 'r2': 1});
  expect(p.routeName('r2'), '04L · Lahug');
});
test('routeName falls back to raw id for unknown route', () async {
  final p = build(operatorAdapter(fleet: [vehicleJson(routeId: 'ghost')]));
  await p.load();
  expect(p.routeName('ghost'), 'ghost');
});
test('load failure sets generic error', () async {
  final p = build(operatorAdapter(fleetStatus: 500));
  await p.load();
  expect(p.isLoading, isFalse);
  expect(p.hasData, isFalse);
  expect(p.error, "Couldn't load fleet data. Try again.");
});
test('connection error maps to connectivity message', () async {
  final p = build(FakeAdapter((o) async => throw DioException.connectionError(
      requestOptions: o, reason: 'offline')));
  await p.load();
  expect(p.error, "Can't reach the server. Check your connection.");
});
test('refresh failure keeps previous data', () async {
  var fail = false;
  final ok = operatorAdapter(fleet: [vehicleJson()]);
  final p = build(FakeAdapter((o) => fail ? Future.value(jsonBody({}, status: 500)) : ok.handler(o)));
  await p.load();
  final stamp = p.lastUpdated;
  fail = true;
  expect(await p.refresh(), isFalse);
  expect(p.totalVehicles, 1);
  expect(p.lastUpdated, stamp);
  expect(p.error, isNotNull);
});
test('polling refreshes and stops', () async {
  final a = operatorAdapter();
  final p = build(a);
  p.startPolling(const Duration(milliseconds: 20));
  await Future.delayed(const Duration(milliseconds: 75));
  p.stopPolling();
  final count = a.requests.length;
  expect(count, greaterThanOrEqualTo(4)); // ≥2 ticks × (fleet + routes)
  await Future.delayed(const Duration(milliseconds: 60));
  expect(a.requests.length, count);
  expect(p.isPolling, isFalse);
});
test('overlapping poll ticks are skipped while a refresh is in flight', () async {
  final a = operatorAdapter(delay: const Duration(milliseconds: 100));
  final p = build(a);
  p.startPolling(const Duration(milliseconds: 20));
  await Future.delayed(const Duration(milliseconds: 90));
  p.stopPolling();
  expect(a.requests.length, 2); // one fleet + one routes
});
test('dispose during in-flight load does not throw', () async {
  final p = build(operatorAdapter(delay: const Duration(milliseconds: 50)));
  final f = p.load();
  p.dispose();
  await f; // would throw "used after being disposed" if notifyListeners ran
});
```

- [ ] **Step 2: Run to verify it fails** — `flutter test test/providers/operator_provider_test.dart` → FAIL.
- [ ] **Step 3: Implement** `OperatorProvider` per the interface above (a single `_fetch({required bool initial})` shared by `load`/`refresh`; `_inFlight` flag for the skip; `Timer.periodic` for polling).
- [ ] **Step 4: Run to verify it passes** — same command → PASS.
- [ ] **Step 5: Commit** — `git add lib/providers/operator_provider.dart test/providers/operator_provider_test.dart && git commit -m "feat(operator): add OperatorProvider with polling"`

---

### Task 4: Shared operator widgets

**Files:**
- Create: `lib/widgets/operator/status_pill.dart`
- Create: `lib/widgets/operator/kpi_card.dart`
- Create: `lib/widgets/operator/operator_tab_body.dart`
- Test: `test/widgets/operator_widgets_test.dart`

**Interfaces:**
- Consumes: `OperatorProvider` (Task 3), `VehicleStatusGroup` (Task 1).
- Produces:
  - `Color statusColor(VehicleStatusGroup g)` → active `AppColors.success`, idle `AppColors.accent`, offline `AppColors.error`.
  - `StatusPill({required String rawStatus})` — rounded `AppRadius.chip` pill, tinted background (colour at alpha 0.12), text = `rawStatus` (or `'unknown'` if empty), coloured by `fromRaw`.
  - `KpiCard({required String label, required String value, required IconData icon, required Color color})` — white card, `AppShadows.card`, coloured icon chip, big value, grey label.
  - `OperatorTabBody({required WidgetBuilder builder})` — watches `OperatorProvider`:
    - `isLoading && !hasData` → centered `CircularProgressIndicator`;
    - `error != null && !hasData` → icon `AppIcons.errorRetry`, the error text, `FilledButton` labelled `Retry` calling `load()`;
    - otherwise `RefreshIndicator(onRefresh: () => refreshWithFeedback(context), child: builder(context))`. The builder must return a scrollable.
  - `Future<void> refreshWithFeedback(BuildContext context)` — calls `refresh()`; on `false` and still mounted, shows `SnackBar(content: Text(provider.error ?? ...))`.
  - `OperatorEmptyView({required IconData icon, required String message})` — centered icon + grey text, for tabs' empty states.

- [ ] **Step 1: Write the failing tests** — pump each inside `MaterialApp` + `ChangeNotifierProvider<OperatorProvider>.value`:
  - `StatusPill(rawStatus: 'signal_lost')` shows text `signal_lost`; its text colour equals `AppColors.error`.
  - `StatusPill(rawStatus: '')` shows `unknown`.
  - `OperatorTabBody` with a provider whose adapter delays 50 ms: after `load()` started and one `pump()`, finds `CircularProgressIndicator`; after `pumpAndSettle`, finds builder content `Text('content')`.
  - `OperatorTabBody` with `fleetStatus: 500`: shows `Couldn't load fleet data. Try again.` and `Retry`; tapping `Retry` adds new requests to the adapter.
  - Refresh failure with existing data: after successful load, switch adapter to fail, call `refreshWithFeedback` via a button in the builder → `SnackBar` with the error text appears and `Text('content')` is still shown.
- [ ] **Step 2: Run to verify it fails** — `flutter test test/widgets/operator_widgets_test.dart` → FAIL.
- [ ] **Step 3: Implement** the three files.
- [ ] **Step 4: Run to verify it passes** — same command → PASS.
- [ ] **Step 5: Commit** — `git add lib/widgets/operator test/widgets/operator_widgets_test.dart && git commit -m "feat(operator): add shared operator widgets"`

---

### Task 5: Responsive shell + Dashboard (overview) tab

**Files:**
- Rewrite: `lib/screens/operator/operator_dashboard.dart`
- Create: `test/support/operator_harness.dart`
- Test: `test/screens/operator_dashboard_test.dart`

**Interfaces:**
- Consumes: Tasks 1–4; `AuthProvider` (`currentUser?.name`, `currentUser?.id`, `logout()`); `LoginScreenHost` (`lib/router/app_router.dart`); `buildDioClient()`.
- Produces:
  - `OperatorDashboard({super.key, OperatorProvider? provider})` — when `provider` is null, builds `OperatorProvider(service: OperatorService(buildDioClient()), operatorId: context.read<AuthProvider>().currentUser?.id)` in `initState` and owns/disposes it; when injected, does **not** dispose it. Calls `load()` in `initState` either way. Router call sites (`const OperatorDashboard()`) stay unchanged.
  - `OperatorDashboard.wideBreakpoint = 1100`, `OperatorDashboard.compactBreakpoint = 700` (static const double).
  - Tabs, in order: `Dashboard` (`Icons.dashboard_outlined`), `Vehicles` (`AppIcons.vehicle`), `Routes` (`Icons.alt_route`), `Live Monitoring` (`AppIcons.location`). Body renders only the selected tab (index switch, not `IndexedStack`). Until Tasks 6–8 land, tabs 1–3 render `OperatorEmptyView` placeholders.
  - Layouts: wide → `Container(key: Key('operator-sidebar'))` 248 px, `AppColors.primary`, logo text `SMART COMMUTE`, nav items, `Sign out` ListTile at bottom; medium → `NavigationRail` with trailing `IconButton(tooltip: 'Sign out')`; compact → `AppBar` (title = tab name) with `PopupMenuButton` item `Sign out`, plus `NavigationBar`.
  - Top bar (wide/medium): tab title, `Updated HH:mm` (24 h, zero-padded, from `lastUpdated`; hidden when null), refresh `IconButton(tooltip: 'Refresh')` → `refreshWithFeedback` (shows small spinner while `isRefreshing`), `CircleAvatar` with initials + name (fallback `Operator`). Compact puts the refresh button in the AppBar actions.
  - Sign out: `await context.read<AuthProvider>().logout()`, then if mounted `Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreenHost()), (_) => false)`.
  - Overview tab (private `_OverviewTab` in the same file), inside `OperatorTabBody`:
    - Greeting `Good morning|afternoon|evening, <first name or 'Operator'>` (hour < 12 / < 18 / else).
    - KPI `Wrap`: `Total vehicles`, `Active`, `Idle`, `Offline`, `Routes in service` (`activeRoutes.length`). Each `KpiCard` width = (available − gaps)/columns where columns = 5 wide, 3 medium, 2 compact (1 below 400 px).
    - `Fleet status` card: segmented bar (`Row` of `Expanded(flex: count)` coloured with `statusColor`, skipping zero counts) + legend `Active 2 (50%)`. When `totalVehicles == 0`: text `No vehicles registered yet.` instead of the bar.
    - `Vehicles by route` card: one row per entry of `vehiclesByRoute` sorted desc: `routeName(id)`, `LinearProgressIndicator(value: count / max)`, count.
    - `Needs attention` card: up to 5 offline-group vehicles: plate, `routeName`, `StatusPill`; when none, `All vehicles reporting`.
  - Test harness `test/support/operator_harness.dart`:
    - `Future<OperatorProvider> pumpOperator(WidgetTester t, {required FakeAdapter adapter, Size size = const Size(1280, 900), Widget Function(OperatorProvider p)? child})` — sets `t.view.physicalSize = size`, `devicePixelRatio = 1`, `addTearDown(t.view.reset)`; builds provider; pumps `MaterialApp(home: MultiProvider([AuthProvider.value(AuthProvider(apiService: ApiService(dio: fakeDio(adapter)))), OperatorProvider.value(p)], child: child?.call(p) ?? OperatorDashboard(provider: p)))`; `pumpAndSettle`; returns provider.
    - `List<Map<String, dynamic>> longNameFleet()` — 3 vehicles with 40-char plates on a route with a 60-char name (Review Focus 5).

- [ ] **Step 1: Write the failing tests** (`test/screens/operator_dashboard_test.dart`)

```dart
testWidgets('shows KPI values from the fleet', (t) async {
  await pumpOperator(t, adapter: operatorAdapter(
    fleet: [vehicleJson(id: 'a'), vehicleJson(id: 'b', status: 'idle'), vehicleJson(id: 'c', status: 'offline')],
    routes: [routeJson()],
  ));
  expect(find.text('Total vehicles'), findsOneWidget);
  expect(find.widgetWithText(KpiCard, '3'), findsOneWidget);
  expect(find.text('Needs attention'), findsOneWidget);
  expect(find.textContaining('Updated '), findsOneWidget);
});
testWidgets('empty fleet shows message instead of status bar', (t) async {
  await pumpOperator(t, adapter: operatorAdapter());
  expect(find.text('No vehicles registered yet.'), findsOneWidget);
  expect(t.takeException(), isNull);
});
testWidgets('first-load error shows Retry and retries', (t) async {
  final a = operatorAdapter(fleetStatus: 500);
  await pumpOperator(t, adapter: a);
  final before = a.requests.length;
  await t.tap(find.text('Retry'));
  await t.pumpAndSettle();
  expect(a.requests.length, greaterThan(before));
});
testWidgets('wide layout uses sidebar', (t) async {
  await pumpOperator(t, adapter: operatorAdapter(), size: const Size(1200, 800));
  expect(find.byKey(const Key('operator-sidebar')), findsOneWidget);
});
testWidgets('medium layout uses NavigationRail', (t) async {
  await pumpOperator(t, adapter: operatorAdapter(), size: const Size(900, 800));
  expect(find.byType(NavigationRail), findsOneWidget);
});
testWidgets('compact layout uses bottom NavigationBar', (t) async {
  await pumpOperator(t, adapter: operatorAdapter(), size: const Size(400, 800));
  expect(find.byType(NavigationBar), findsOneWidget);
});
testWidgets('nav switches tabs', (t) async {
  await pumpOperator(t, adapter: operatorAdapter());
  await t.tap(find.text('Routes').first);
  await t.pumpAndSettle();
  expect(find.text('Routes in service'), findsNothing);
});
testWidgets('no overflow at 360 px with long names', (t) async {
  await pumpOperator(t, adapter: operatorAdapter(fleet: longNameFleet(), routes: [routeJson(name: 'X' * 60)]),
      size: const Size(360, 740));
  expect(t.takeException(), isNull);
});
```

- [ ] **Step 2: Run to verify it fails** — `flutter test test/screens/operator_dashboard_test.dart` → FAIL.
- [ ] **Step 3: Implement** the shell and overview tab per the interface above.
- [ ] **Step 4: Run to verify it passes** — same command → PASS; also `flutter analyze lib/screens/operator lib/widgets/operator lib/providers/operator_provider.dart` → no issues.
- [ ] **Step 5: Manual check** — run the app (`flutter run -d chrome`), log in as an operator, resize the window across 1100/700 px, press Sign out → returns to login.
- [ ] **Step 6: Commit** — `git add lib/screens/operator/operator_dashboard.dart test/support/operator_harness.dart test/screens/operator_dashboard_test.dart && git commit -m "feat(operator): responsive shell and overview tab"`

---

### Task 6: Vehicles tab

**Files:**
- Fill: `lib/screens/operator/operator_vehicles.dart`
- Modify: `lib/screens/operator/operator_dashboard.dart` (tab index 1 → `const OperatorVehiclesTab()`)
- Test: `test/screens/operator_vehicles_test.dart`

**Interfaces:**
- Consumes: `OperatorProvider`, `OperatorTabBody`, `OperatorEmptyView`, `StatusPill`, `VehicleStatusGroup`, `pumpOperator(child: ...)`.
- Produces: `OperatorVehiclesTab({super.key})` (StatefulWidget; holds query + `VehicleStatusGroup? filter`).
  - Search `TextField` hint `Search plate number`, case-insensitive `contains` on `plateNumber`.
  - `ChoiceChip`s: `All (n)`, `Active (n)`, `Idle (n)`, `Offline (n)`.
  - Width ≥ 700: `DataTable` columns `Plate`, `Route`, `Status`, `Crowd`, `Last position` (horizontal `SingleChildScrollView` around it). < 700: `Card` per vehicle with the same fields.
  - Crowd: `crowdLevel` or `—`. Last position: `lat.toStringAsFixed(4), lng.toStringAsFixed(4)` or `—`. Route: `routeName(routeId)`.
  - No vehicles at all → `OperatorEmptyView(icon: AppIcons.vehicle, message: 'No vehicles registered yet.')`; filtered to none → `No vehicles match your filters.`

- [ ] **Step 1: Write the failing tests** — fleet `[vehicleJson(id:'a', plate:'ABC-123'), vehicleJson(id:'b', plate:'XYZ-999', status:'idle', routeId:'ghost', lat:10.31234, lng:123.89876)]`, routes `[routeJson()]`, `child: (_) => const Scaffold(body: OperatorVehiclesTab())`:
  - shows both plates and `Active (1)`, `Idle (1)`;
  - typing `xyz` → `ABC-123` gone, `XYZ-999` shown;
  - tapping `Active (1)` → only `ABC-123`;
  - typing `nope` → `No vehicles match your filters.`;
  - unknown route shows `ghost`; position shows `10.3123, 123.8988`; `—` appears for missing crowd;
  - at 1200 px finds `DataTable`; at 400 px finds no `DataTable` and finds `Card`s;
  - at 360 px with `longNameFleet()` → `t.takeException()` is null.
- [ ] **Step 2: Run to verify it fails** — `flutter test test/screens/operator_vehicles_test.dart` → FAIL.
- [ ] **Step 3: Implement** `OperatorVehiclesTab` and wire it into the shell.
- [ ] **Step 4: Run to verify it passes** — `flutter test test/screens/operator_vehicles_test.dart test/screens/operator_dashboard_test.dart` → PASS.
- [ ] **Step 5: Commit** — `git add lib/screens/operator/operator_vehicles.dart lib/screens/operator/operator_dashboard.dart test/screens/operator_vehicles_test.dart && git commit -m "feat(operator): vehicles tab with search and filters"`

---

### Task 7: Routes tab

**Files:**
- Fill: `lib/screens/operator/operator_routes.dart`
- Modify: `lib/screens/operator/operator_dashboard.dart` (tab index 2 → `const OperatorRoutesTab()`)
- Test: `test/screens/operator_routes_test.dart`

**Interfaces:**
- Consumes: `OperatorProvider.routes`, `vehiclesByRoute`, `OperatorTabBody`, `OperatorEmptyView`.
- Produces: `OperatorRoutesTab({super.key})`.
  - Grid via `LayoutBuilder`: columns = 3 (≥ 1100), 2 (≥ 700), 1 otherwise; cards in a `Wrap` (not fixed-height `GridView`, so expanded cards can grow).
  - Card: code badge (`AppColors.primary` bg, white text), name (max 2 lines, ellipsis), badge `Active` (`AppColors.success`) / `Inactive` (`AppColors.textSecondary`), `<n> stops`, `<n> vehicles` (0 when absent from map).
  - Tapping a card toggles an expanded stop list ordered by `sequence`: `1. Stop 1`, `2. Stop 2`…
  - No routes → `OperatorEmptyView(icon: Icons.alt_route, message: 'No routes found.')`.

- [ ] **Step 1: Write the failing tests** — routes `[routeJson(stopCount: 3), routeJson(id:'r2', code:'04L', name:'Lahug', isActive:false, stopCount: 1)]`, fleet two vehicles on `r1`:
  - finds `01K`, `04L`, `Active`, `Inactive`, `3 stops`, `2 vehicles`, `0 vehicles`;
  - `Stop 2` not found; tap `01K` card → `2. Stop 2` found; tap again → gone;
  - empty routes → `No routes found.`;
  - 360 px with `routeJson(name: 'X' * 60)` → no exception.
- [ ] **Step 2: Run to verify it fails** — `flutter test test/screens/operator_routes_test.dart` → FAIL.
- [ ] **Step 3: Implement** and wire into the shell.
- [ ] **Step 4: Run to verify it passes** — `flutter test test/screens/operator_routes_test.dart test/screens/operator_dashboard_test.dart` → PASS.
- [ ] **Step 5: Commit** — `git add lib/screens/operator/operator_routes.dart lib/screens/operator/operator_dashboard.dart test/screens/operator_routes_test.dart && git commit -m "feat(operator): routes tab with expandable stops"`

---

### Task 8: Live Monitoring tab

**Files:**
- Fill: `lib/screens/operator/operator_livemonitoring.dart`
- Modify: `lib/screens/operator/operator_dashboard.dart` (tab index 3 → `const OperatorLiveMonitoringTab()`)
- Test: `test/screens/operator_livemonitoring_test.dart`

**Interfaces:**
- Consumes: `OperatorProvider` (`vehicles`, `startPolling`, `stopPolling`, `isPolling`, `routeName`), `MapConfig` (`lib/config/map_config.dart`), `statusColor`, `StatusPill`.
- Produces: `OperatorLiveMonitoringTab({super.key, this.showTiles = true})` (StatefulWidget).
  - `initState`: `context.read<OperatorProvider>().startPolling()`; `dispose`: `stopPolling()` (cache the provider reference in `initState` for use in `dispose`).
  - Header strip: green dot + `Live · refreshing every 15 s`.
  - `FlutterMap` with `MapController`, `initialCenter: MapConfig.defaultCenter`, `initialZoom: 13`, `minZoom`/`maxZoom` from `MapConfig`, `cameraConstraint: CameraConstraint.contain(bounds: MapConfig.serviceArea)`; `TileLayer(urlTemplate: MapConfig.tileUrl, userAgentPackageName: MapConfig.userAgentPackageName)` only when `showTiles`; `MarkerLayer` with one `Marker` per vehicle that has `lastPosition` — `Key('marker-<id>')`, circle in `statusColor`, selected one larger (40 vs 28) with a plate label.
  - List item per vehicle: `Key('vehicle-tile-<id>')`, plate, `routeName`, `StatusPill`; vehicles without position show `No GPS fix` and are not tappable-to-center. Tapping a tile or marker selects it and calls `mapController.move(LatLng(lat, lng), 16)`.
  - Width ≥ 900: `Row(map Expanded, SizedBox(width: 320, list))`. < 900: `Stack(map, DraggableScrollableSheet(initialChildSize: 0.25, minChildSize: 0.12, maxChildSize: 0.6, list))`.
  - No vehicles → map still shows, list area shows `No vehicles registered yet.`
  - This tab is not wrapped in `RefreshIndicator` (map gestures); it still uses `OperatorTabBody`'s loading/error states — give `OperatorTabBody` an optional `bool refreshable = true` and pass `false` here (update Task 4's widget; add one test there that `refreshable: false` renders no `RefreshIndicator`).

- [ ] **Step 1: Write the failing tests** — fleet `[vehicleJson(id:'a', lat:10.31, lng:123.89), vehicleJson(id:'b', plate:'NOGPS-1', status:'offline')]`, `child: (_) => const Scaffold(body: OperatorLiveMonitoringTab(showTiles: false))`:
  - finds `Key('marker-a')`, no `Key('marker-b')`; finds `No GPS fix`; finds `Live · refreshing every 15 s`;
  - after pump, `provider.isPolling` is true; pumping a `SizedBox` in place of the tab → `isPolling` false;
  - tapping `Key('vehicle-tile-a')` → marker `a` is the selected size (find its `SizedBox`/`Container` width 40);
  - at 1200 px the list is beside the map (finds `DraggableScrollableSheet` = nothing); at 400 px finds `DraggableScrollableSheet`;
  - empty fleet → `No vehicles registered yet.`, no exception;
  - 360 px with `longNameFleet()` → no exception.
  - End each test with `provider.stopPolling()` (or rely on tab dispose) so no timers remain pending.
- [ ] **Step 2: Run to verify it fails** — `flutter test test/screens/operator_livemonitoring_test.dart` → FAIL.
- [ ] **Step 3: Implement** the tab, the `refreshable` flag, and wire into the shell.
- [ ] **Step 4: Run to verify it passes** — `flutter test test/screens/operator_livemonitoring_test.dart test/widgets/operator_widgets_test.dart test/screens/operator_dashboard_test.dart` → PASS.
- [ ] **Step 5: Manual check** — `flutter run -d chrome`, open Live Monitoring: tiles load, markers appear for vehicles with positions, switching tabs stops network polling (DevTools network panel shows no `/fleet` every 15 s after leaving).
- [ ] **Step 6: Commit** — `git add lib/screens/operator/operator_livemonitoring.dart lib/screens/operator/operator_dashboard.dart lib/widgets/operator/operator_tab_body.dart test/screens/operator_livemonitoring_test.dart test/widgets/operator_widgets_test.dart && git commit -m "feat(operator): live monitoring map with polling"`

---

### Task 9: Full verification

- [ ] **Step 1:** `flutter analyze` → no new issues in `lib/screens/operator`, `lib/widgets/operator`, `lib/providers/operator_provider.dart`, `lib/services/operator_service.dart`, `lib/models/vehicle_status.dart`, or the new tests.
- [ ] **Step 2:** `flutter test` → all new tests pass; only failure is the pre-existing `test/widget_test.dart` (missing `main`).
- [ ] **Step 3:** `grep -rn "Color(0x" lib/screens/operator lib/widgets/operator` → no matches.
