# Trip Planner & Fare Estimate — Design

**Date:** 2026-10-01
**Branch:** Velez
**Status:** Draft, pending review

## Goal

Let a logged-in commuter, from the **Routes** tab, (1) plan a trip from their
current location to a destination and (2) view a fare breakdown for the route
option they choose, working end-to-end against the FastAPI backend.

## Decisions

| Topic | Decision |
|---|---|
| Source of fare/ETA | Trust `POST /trip-plan` as-is. No client-side fare math. |
| Origin | Always the commuter's current GPS location. No manual origin. |
| Destination | Both: searchable stop list **and** "Pick on map". |
| "View fare estimate" | Fare breakdown of the commuter's selected option. |
| Structure | Dedicated screen + service + provider (not inside `commuter_dashboard.dart`). |
| Guests | Tiles disabled with a "Sign in to plan trips" banner (backend is commuter-only). |

**Known limitation (as-is system):** the backend planner is currently a stub.
It returns one leg on the first active route with `fare = 13.0` and
`eta_min = 5`. The frontend displays whatever the backend returns. When the
teammate finishes the planner, the frontend needs no changes.

## Backend contract (existing, not changed)

`POST /trip-plan`, requires `Authorization: Bearer <commuter token>`.

Request:
```json
{
  "origin":      {"type": "Point", "coordinates": [lng, lat]},
  "destination": {"type": "Point", "coordinates": [lng, lat]},
  "preferences": {"minimize": "time" | "fare" | "transfers", "max_transfers": 2}
}
```

Response:
```json
{
  "options": [{
    "rank": 1, "total_eta_min": 5, "total_fare": 13.0, "transfers": 0,
    "legs": [{
      "route_id": "...", "route_name": "...", "eta_min": 5, "fare": 13.0,
      "board_stop":  {"id","name","sequence","location","route_ids","landmark"},
      "alight_stop": {"id","name","sequence","location","route_ids","landmark"}
    }]
  }],
  "generated_at": "2026-10-01T08:00:00"
}
```

`options: []` means no route found (HTTP 200).

## Architecture

### Model — `lib/models/trip_plan.dart`
- `TripPreference` enum: `time`, `fare`, `transfers` (serialized as `minimize`).
- `TripPlanResponse { List<RouteOption> options; DateTime generatedAt }`
- `RouteOption { int rank; List<RouteLeg> legs; int totalEtaMin; double totalFare; int transfers }`
- `RouteLeg { String routeId; String routeName; StopModel boardStop; StopModel alightStop; int etaMin; double fare }`
- Reuses the existing `StopModel` from `lib/models/models.dart`.

### Service — `lib/services/trip_plan_service.dart`
- `TripPlanService(Dio dio)`, same pattern as `StopsService` / `RoutesService`.
- `Future<TripPlanResponse> planTrip({required LatLng origin, required LatLng destination, TripPreference preference = TripPreference.time})`
- Coordinates are sent as GeoJSON **[lng, lat]**.
- Constructed with `buildDioClient()` so the auth interceptor attaches and refreshes the token.
- Lets `DioException` bubble up; the provider maps it.

### Provider — `lib/providers/trip_plan_provider.dart` (`ChangeNotifier`)
- State: `origin`, `destination`, `destinationLabel`, `preference`,
  `status` (`idle | locating | loading | success | empty | error`),
  `options`, `selectedOption`, `errorMessage`.
- Methods: `locateOrigin()`, `setDestination(LatLng, String label)`,
  `setPreference(TripPreference)`, `plan()`, `selectOption(RouteOption)`.
- `plan()` is a no-op when origin or destination is missing, or a request is already in flight.
- Location access goes through a small injectable `LocationSource` so the provider is testable without Geolocator.
- Error mapping:
  - 401/403 → "Sign in as a commuter to plan trips."
  - connection error / timeout → "Can't reach the server. Check your connection."
  - anything else → "Something went wrong. Please try again."
  - location denied → "Location permission is needed to plan a trip."
  - location services off → "Turn on location services to plan a trip."
- Provided at the commuter dashboard level (wraps the dashboard `Scaffold`) so the
  Routes-tab "View fare estimate" tile can read `selectedOption` after the planner closes.

### Screens & widgets
- **Routes tab** (in `commuter_dashboard.dart`): replace placeholder `onTap`s.
  - "Plan a trip" → push `TripPlannerScreen`.
  - "View fare estimate" → `showFareBreakdownSheet(selectedOption)`, or a
    "Plan a trip first" snackbar with an action to open the planner.
  - Guests: both tiles disabled + "Sign in to plan trips" banner.
- **`lib/screens/commuter/trip_planner_screen.dart`**
  1. "From: My location" card — auto-locates on open; spinner; retry on error.
  2. "To" field → stop search sheet (filter `/stops` by name/landmark, `StopImage` thumbnails),
     plus a "Pick on map" button.
  3. Preference chips: Fastest / Cheapest / Fewest transfers (default Fastest).
  4. "Find routes" button — enabled only when origin and destination are set and not loading.
  5. Results list — card per option: rank, leg route names joined with "→",
     ₱ total fare, total ETA, transfers. Loading / empty / error states.
     Tapping a card selects it and opens the fare breakdown sheet.
- **`lib/screens/commuter/pick_destination_screen.dart`** — full-screen `FlutterMap`
  constrained to the Metro Cebu service area, center crosshair, "Set destination"
  button. Returns the center `LatLng`; label becomes "Dropped pin (lat, lng)" with coordinates shown to 4 decimals.
- **`lib/widgets/fare_breakdown_sheet.dart`** — modal bottom sheet: total fare (large),
  total ETA, transfers; one row per leg (route name, "Board at X → Alight at Y",
  leg ETA, leg fare); footer "Estimated fare — actual fare may vary."
  Fares formatted as `₱13.00`.

## Edge cases
- Location services off / permission denied forever → message + Retry; "Find routes" disabled.
- Destination within ~20 m of origin → blocked with "You're already there."
- Double tap on "Find routes" → ignored while loading.
- Leaving the planner mid-request → safe; provider outlives the screen.
- Stub placeholder stop (`id == "0"` or coordinates `[0, 0]`) → shown as "Your location".
- Origin outside Metro Cebu → still sent; backend decides.

## Testing
Uses `flutter_test` only; Dio is faked with an in-memory `HttpClientAdapter`.
- `test/models/trip_plan_test.dart` — parse a realistic response (incl. stub `[0,0]` stop) and empty options.
- `test/services/trip_plan_service_test.dart` — request body uses `[lng, lat]` and the right `minimize`.
- `test/providers/trip_plan_provider_test.dart` — status transitions, 401 mapping, no-op without destination, double-tap guard.
- `test/widgets/fare_breakdown_sheet_test.dart` — total, one row per leg, `₱` formatting.
- Manual test drive in the running app: GPS origin, stop search, pick on map, results, breakdown, guest mode.

## Out of scope
- Route geometry preview on the map.
- Saved / recent trips.
- `preferred_arrival` (scheduled arrival time).
- Changes to the backend.
