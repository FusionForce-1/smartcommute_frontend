# Smart Commute — Flutter Auth UI (Emae's scope)

This is a **UI-only** slice of the Smart Commute Flutter app: the four auth
screens from the finalized mockups, plus the shared visual system and the 11
reusable widgets from §E3 of the system layout doc.

**Scope covered:**
- `lib/config/theme_config.dart` — §E1 Visual Style Guide as an `AppTheme`
- `lib/widgets/*.dart` — all 11 §E3 reusable widgets (param-only, no API calls)
- `lib/widgets/auth/*.dart` — small auth-screen-only helpers (logo lockup,
  header banner, Google button, text field) — **not** part of the official
  11-widget catalog, kept separate so that catalog stays exactly as spec'd
- `lib/screens/auth/login_screen.dart`
- `lib/screens/auth/register_screen.dart`
- `lib/screens/auth/forgot_password_screen.dart`
- `lib/screens/auth/verify_otp_screen.dart`
- `lib/main.dart` — a **mock router** so the four screens are click-through
  navigable with zero backend/state-management dependencies

**Not covered here** (out of scope per this request): Splash screen,
Commuter/Driver/Operator dashboards, map screens, and everything in Kent's
(K-) and Francis's (F-) sections of the doc.

## Running the preview

This folder is a normal Flutter project skeleton (missing only the
`android/`, `ios/`, etc. platform folders that `flutter create .` generates).
From an existing Flutter project, or after running `flutter create .` inside
this folder:

```bash
flutter pub get
flutter run
```

It boots straight to `LoginScreen` (see `initialRoute` in `main.dart`) so you
can click through Login → Forgot Password → Verify OTP, and Login → Register,
exactly like the mockups.

## What's mocked vs. real

Every screen takes plain callback parameters (`onLogin`, `onRegister`,
`onSendOtp`, `onVerifyOtp`, `onGoogleSignIn`, `onGuestContinue`) instead of
calling `ApiService`/`AuthProvider`/`Dio` directly. That's intentional:

- **Widgets and screens never import `provider`, `dio`, or any networking
  package.** They are pure Flutter + the params passed in.
- `main.dart` is a **mock router**, not the real F4 `app_router.dart`. It
  wires the navigation-only callbacks (Forgot Password, Create Account, Back)
  directly to `Navigator`, and leaves every backend-calling callback as
  `null`, which makes the screen fall back to a "Preview only" `SnackBar`
  instead of crashing.
- Every place Francis needs to plug in real logic is marked
  `// TODO(Francis): ...` with the exact F1/F2/F3 method it should call, per
  the system layout doc.

To wire it up for real: build the real `AuthProvider` (F3) + `ApiService`
(F1), replace `main.dart`'s mock `routes` map with the real `app_router.dart`
(F4), and pass the real async functions into each screen's callback params —
no changes needed inside `lib/screens/` or `lib/widgets/` themselves.

## Fix for "'C:\Users\Emae' is not recognized..." on Windows

If you hit this error running `flutter run`:

```
'C:\Users\Emae' is not recognized as an internal or external command...
Building native assets for package:objective_c failed.
```

**Root cause:** a few packages (`google_fonts`, `cached_network_image`)
transitively depend on `path_provider` → `path_provider_foundation` →
`package:objective_c`, and that package ships a native build hook. Flutter's
hook runner has a bug on Windows where it doesn't quote paths containing a
space, so it breaks as soon as it's invoked from a folder path with a space
in it — including `C:\Users\Emae D. Calonia\...`, since the space is in the
**Windows username itself**, not just one specific folder. That means the
crash would follow you to Desktop, Documents, or anywhere else under your
user folder too, not just this Downloads copy.

**Fix applied in this version:** none of the four auth screens actually
`import` any of the §E5 packages listed in the original pubspec (they were
only added there to match the doc, ahead of the screens that will need
them). So this pubspec now only depends on core Flutter + `cupertino_icons`,
and Poppins is bundled locally under `assets/fonts/` (declared via
`flutter.fonts`, OFL-licensed, pulled from the official `google/fonts` repo)
instead of fetched at runtime via `google_fonts`. With no package left in
the tree that ships a native build hook, `flutter run` no longer tries to
build one — so the project runs from **any** folder, spaces and all.

Run `flutter clean && flutter pub get` after pulling this update if you
previously ran `flutter pub get` on the old pubspec.

If/when `flutter_map`, `cached_network_image`, `lottie`, etc. get added back
in for the map/list screens (§E5), re-test from a spaced path — if the
crash reappears, it's a sign that package pulled in `path_provider` again.

## Known deviations from the written §E1 spec

The button/pill corner radius in the finalized mockups is visibly larger
(stadium-shaped) than the documented `8px` button radius token. `AppRadius`
in `theme_config.dart` follows the mockups and flags this explicitly — worth
a quick team decision on which is canonical (update the doc, or redraw the
mockups) before the defense.
