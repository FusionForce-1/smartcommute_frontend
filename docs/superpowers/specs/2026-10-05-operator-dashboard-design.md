# Operator Dashboard Redesign — Design

**Date:** 2026-10-05
**Branch:** Velez
**Status:** Draft, pending review

## Goal

Turn the operator dashboard from a static mock (hard-coded `0`s, placeholder
tabs, non-working Sign out) into a working, responsive, read-only console with
four tabs — **Dashboard, Vehicles, Routes, Live Monitoring** — backed by the
existing fleet and routes endpoints.

## Decisions

| Topic | Decision |
|---|---|
| Scope | Redesign shell + all four tabs. |
| Data source | Existing `GET /fleet` and `GET /routes`. No new endpoints. |
| Editing | Read-only. No add/edit/delete (no backend endpoints exist). |
| State | One shared `OperatorProvider` used by all tabs (one fetch, consistent numbers). |
| Live updates | Polling every 15 s, only while Live Monitoring is visible. No WebSocket for now. |
| Styling | `AppColors` / `AppRadius` / `AppSpacing` / `AppShadows` from `theme_config.dart`; no hard-coded hex. |
| Sign out | `AuthProvider.logout()` then `pushAndRemoveUntil(LoginScreenHost)`, same as commuter dashboard. |

## Backend contract (existing, not changed)

- `GET /fleet?operator_id=<id>` → `List<VehicleModel>` JSON
  (`id`, `plate_number`, `route_id`, `status`, `crowd_level?`, `last_position?`).
  `operator_id` is taken from `AuthProvider.currentUser?.id` when available.
- `GET /routes` → `List<RouteModel>` JSON (`id`, `name`, `code`, `stops`,
  `fare_matrix`, `is_active`).

Vehicle `status` is a free string from the backend. The UI normalises it
(case-insensitive) into three display groups:

| Group | Matches | Colour |
|---|---|---|
| Active | `active`, `in_service`, `on_route`, `moving` | `AppColors.success` |
| Idle | `idle`, `parked`, `standby` | `AppColors.accent` |
| Offline | `offline`, `signal_lost`, `inactive`, anything else | `AppColors.error` |

Unknown statuses fall into **Offline** but the raw string is still shown on the
status pill so nothing is hidden.

## Architecture

```
lib/services/operator_service.dart        NEW  OperatorService(Dio): getFleet(), getRoutes()
lib/providers/operator_provider.dart      NEW  ChangeNotifier: load/refresh/polling + derived counts
lib/models/vehicle_status.dart            NEW  VehicleStatusGroup enum + fromRaw() normaliser
lib/screens/operator/operator_dashboard.dart  REWRITE  responsive shell + Dashboard tab
lib/screens/operator/operator_vehicles.dart   FILL     Vehicles tab
lib/screens/operator/operator_routes.dart     FILL     Routes tab
lib/screens/operator/operator_livemonitoring.dart FILL Live Monitoring tab
lib/widgets/operator/                     NEW  small shared widgets (KPI card, status pill, state views)
```

`OperatorService` follows the `TripPlanService(Dio)` pattern so the provider can
be unit-tested with the existing `test/support/fake_dio.dart`. `ApiService` is
not changed.

`OperatorDashboard` creates the `OperatorProvider` in its `State` (built with
`OperatorService(buildDioClient())`), calls `load()` in `initState`, disposes it
in `dispose`, and exposes it with `ChangeNotifierProvider.value` — same pattern
as `CommuterDashboard` / `TripPlanProvider`. A test-only constructor parameter
lets widget tests inject a provider.

### OperatorProvider

State:
- `List<VehicleModel> vehicles`, `List<RouteModel> routes`
- `bool isLoading` (first load), `bool isRefreshing` (subsequent)
- `String? error` (user-facing message), `DateTime? lastUpdated`

Methods:
- `load()` — fetches fleet + routes in parallel; sets `error` on failure,
  keeps previous data if a refresh fails.
- `refresh()` — same, without the full-screen loading state.
- `startPolling([Duration interval = 15s])` / `stopPolling()` — periodic
  `refresh()`; ignores ticks while a refresh is in flight; cancelled on dispose.

Derived getters:
- `totalVehicles`, `countFor(VehicleStatusGroup)`
- `activeRoutes` (routes with `isActive`)
- `vehiclesByRoute` → `Map<String routeId, int>`
- `routeName(String routeId)` → `"CODE · Name"` or the raw id if unknown

Error text: `DioException` connection/timeout → "Can't reach the server.
Check your connection."; other → "Couldn't load fleet data. Try again."

## UI

### Shell (responsive)

| Width | Navigation |
|---|---|
| ≥ 1100 px | Full 248 px sidebar (`AppColors.primary`), logo, labels, Sign out at bottom |
| 700–1099 px | `NavigationRail` (icons only, labels on selected) |
| < 700 px | `AppBar` + bottom `NavigationBar`; Sign out in the AppBar overflow menu |

Top bar (wide layouts): tab title, "Updated hh:mm" text, refresh `IconButton`
(spinner while refreshing), avatar with operator initials + name from
`AuthProvider.currentUser`. Background `AppColors.backgroundIceBlue`, cards
white with `AppRadius.card` and `AppShadows.card`.

Every tab handles the same four states through shared widgets:
loading (centered spinner), error (message + Retry), empty (icon + text),
data. Content is wrapped in `RefreshIndicator`.

### Dashboard tab
- Greeting header ("Good morning, <name>") + date.
- KPI row (wraps to 2×2 / 1 column on narrow): **Total vehicles**,
  **Active**, **Idle**, **Offline** — each with coloured icon chip — plus a
  **Routes in service** card.
- **Fleet status** card: a single horizontal segmented bar (Active / Idle /
  Offline proportions) with a legend and percentages.
- **Vehicles by route** card: list of routes with a small proportional bar and
  count, sorted descending.
- **Needs attention** card: up to 5 vehicles in the Offline group (plate,
  route, raw status); "All vehicles reporting" message when none.

### Vehicles tab
- Search field (plate number, case-insensitive) + filter chips
  (All / Active / Idle / Offline, with counts).
- ≥ 700 px: `DataTable` — Plate, Route, Status pill, Crowd, Last position
  (`lat, lng` to 4 dp, "—" if null).
- < 700 px: one card per vehicle with the same fields.
- Empty filter result → "No vehicles match your filters."

### Routes tab
- Grid of route cards (1–3 columns by width): code badge, name,
  Active/Inactive badge, stop count, vehicles assigned (from `vehiclesByRoute`).
- Tap a card → expands (`ExpansionTile`-style) to show ordered stop names.

### Live Monitoring tab
- `FlutterMap` using `MapConfig` (tile URL, bounds, default center, zoom limits).
- One marker per vehicle with a `lastPosition`, coloured by status group;
  selected marker enlarged with plate label.
- ≥ 900 px: map + 320 px side list of vehicles; < 900 px: map with a
  draggable bottom sheet list.
- Tapping a vehicle (list or marker) selects it and moves the map to it.
- Vehicles with no position are listed with "No GPS fix" and are not on the map.
- Header strip: "Live · refreshing every 15 s" indicator.
- Polling: tab calls `startPolling()` when shown and `stopPolling()` when
  hidden/disposed. Only the visible tab is built (shell uses an index switch,
  not `IndexedStack`), so leaving the tab disposes it and stops polling.

## Error handling
- First-load failure → full error state with Retry.
- Refresh failure with existing data → keep data, show a `SnackBar` with the
  error; KPI/tabs keep showing last good values and "Updated" time.
- Sign out failure is already swallowed by `AuthProvider.logout()`; we still
  navigate to login.

## Testing

Unit (`test/providers/operator_provider_test.dart`, `test/models/vehicle_status_test.dart`):
- status normalisation (known values, case, unknown → offline)
- `load()` success populates lists, counts, `vehiclesByRoute`, `lastUpdated`
- `load()` failure sets `error`, `isLoading` false
- `refresh()` failure keeps previous data
- polling triggers refresh and stops after `stopPolling()` / dispose (tested with a short real interval, e.g. 20 ms — no `fake_async` dependency)

Widget (`test/screens/operator_dashboard_test.dart`):
- loading → data: KPI values rendered from fixture
- error state shows Retry and calls `load()` again
- layout: sidebar at 1200 px, rail at 900 px, bottom nav at 400 px
- Vehicles tab: search + chip filter narrow the list
- Routes tab: renders route cards with vehicle counts
- Live Monitoring tab: renders list entries (map tiles are not loaded in tests:
  the tab takes a `bool showTiles = true` constructor flag that tests set to `false`)

Fixtures go in `test/support/operator_fixtures.dart`, reusing `fake_dio.dart`.

## Out of scope
- Creating/editing vehicles or routes.
- WebSocket live positions (can replace polling later inside `OperatorProvider`
  without UI changes).
- Charts libraries — bars are plain `Container`s, no new dependencies.
