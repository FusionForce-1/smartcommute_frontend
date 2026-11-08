# Smart Commute — Frontend

Client side of **Smart Commute**, the integrated public transport information
system for Cebu City:

- **Flutter app** (`lib/`) for commuters, guests, and vehicle drivers — live
  vehicle map, trip planner with step-by-step guidance, operator notices, ride
  reviews, saved routes, and the Driver Dashboard (shift, passengers, route
  status, crowd level, reports to the operator). Built for Android and the web.
- **Web portal** (`web_portal/`) for transport operators and system
  administrators — plain HTML/CSS/JavaScript with Leaflet maps. See
  [`web_portal/README.md`](web_portal/README.md).

The backend (FastAPI + MongoDB) lives in the `Smart-Commute-Backend` repository.

## Requirements

- Flutter 3.44 or later (stable channel); the packages need Dart 3.12+
- Android Studio with the Android SDK, and an emulator or a phone with USB debugging

## Setup

```bash
flutter pub get
cp .env.example .env     # then adjust; see the comments in the file
```

`.env` is packed into the app as an asset (the build fails without it), so it
must hold only public values: the backend's HTTPS and WebSocket addresses, the
Google OAuth **web** client ID, and optional extras. On the Android emulator,
`localhost` is rewritten to `10.0.2.2`; for a real phone on the same Wi-Fi as a
local backend, set `API_BASE_URL_ANDROID` / `WS_BASE_URL_ANDROID` to the laptop's IP.

## Run and build

```bash
flutter run                          # emulator or USB-connected phone
flutter test                         # widget, provider and service tests
flutter build apk --release          # Android installer (direct install)
flutter build appbundle --release    # Android App Bundle for Google Play
flutter build web --release          # web version
```

For the web version, add its address to the backend's `ALLOWED_ORIGINS`.

On Windows, when the project and the pub cache are on different drives, Kotlin's
incremental build cache can fail; add `--android-project-arg=kotlin.incremental=false`
to the `flutter build` command.

## Android release signing

The application ID is `com.fusionforce.smartcommute`. Release builds are signed
with the key described in `android/key.properties` (git-ignored, like the
keystore); copy `android/key.properties.example` and follow the steps in it.
Without that file, release builds fall back to the debug key so they still run,
but Google Play rejects them.

## Google Sign-In

- **Web and backend:** the OAuth *web* client ID goes in `.env`
  (`GOOGLE_WEB_CLIENT_ID`), `web/index.html`, `web_portal/js/config.js`, and the
  backend's `GOOGLE_CLIENT_ID`.
- **Android:** in the same Google Cloud project, add an OAuth client of type
  *Android* for the package name `com.fusionforce.smartcommute` and the SHA-1 of
  every key that signs the app — the debug key
  (`keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android`),
  the upload key, and Google Play's app signing key if you use Play.
- **iOS:** not set up yet. It needs its own bundle identifier, an iOS OAuth
  client (its client ID and reversed client ID go in `ios/Runner/Info.plist`),
  and an Apple Developer account for distribution.

## Web deployment

`.github/workflows/deploy-web.yml` runs the tests, builds the web app, and
deploys it to Vercel on every push to `main` that changes the app. It needs the
repository secrets `APP_ENV_FILE` (the full `.env`), `VERCEL_TOKEN`,
`VERCEL_ORG_ID`, and `VERCEL_PROJECT_ID`.
