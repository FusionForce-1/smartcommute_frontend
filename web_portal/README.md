# Smart Commute — Web Portal Auth Screens (Emae's scope)

Plain HTML/CSS/JS implementation of the four auth screens — **no build
step, no framework, no npm install required to run it.**

## Where this goes in your project

This folder is meant to sit **inside your existing `smartcommute_frontend`
Flutter project**, as its own top-level folder next to `lib/`, `android/`,
`web/`, etc. — not merged into Flutter's own `web/` folder (that one is
reserved for Flutter's web-build output and is managed by Flutter tooling;
mixing this vanilla HTML/CSS/JS portal into it will cause conflicts).

```
smartcommute_frontend/
├── android/
├── ios/
├── lib/            ← Flutter app (screens, widgets, theme_config.dart)
├── web/             ← Flutter's own web-build target, DO NOT touch
├── web_portal/       ← put THIS folder here (Leaflet.js portal / auth screens)
│   ├── index.html
│   ├── css/
│   ├── js/
│   └── assets/
├── windows/, macos/, linux/, test/
├── pubspec.yaml
└── ...
```

Just drag this `web_portal/` folder into the root of `smartcommute_frontend`
alongside `lib/`. It's fully self-contained (its own `css/`, `js/`,
`assets/`) and doesn't touch or depend on anything in `lib/` or Flutter's
`web/` — open `web_portal/index.html` directly, same as before.

**Scope covered:**
- `css/theme.css` — color/spacing/radius/shadow tokens **pixel-sampled
  directly from the mockup PNGs and the source logo file** (see "Colors"
  below) — not the §E1 doc's values, which turned out not to match, and not
  eyeballed guesses either
- `css/components.css` — reusable component styles (buttons, inputs, cards,
  error banner, dividers)
- `css/layout.css` — the white/teal split background for Login/Register
- `css/modal.css` + `js/modal.js` — the Forgot Password / Verify OTP popup
  overlay (see "Forgot Password / Verify OTP is a popup" below)
- `js/components.js` — param-only HTML builder functions (icons, fields,
  buttons, banners) — no `fetch()` calls live inside any of them
- `js/views/login.js`, `register.js` — full pages
- `js/views/authPopup.js` — Forgot Password + Verify OTP as a single
  two-step **popup** flow, launched from Login
- `js/router.js` + `js/main.js` — mock router for Login/Register + bootstrap

## Colors

Pulled with a pixel sampler (not eyeballed) directly from `Web_Login.png`,
`Web_Forgot_Password.png`, `Web_Enter_OTP.png`, `Web_Error.png`, and the
source logo PNG:

| Token | Value | Sampled from |
|---|---|---|
| `--color-primary` | `#1A1E37` | "SMART" wordmark + card titles |
| `--color-secondary` | `#3C889D` | Button fill / background / "COMMUTE" wordmark |
| `--color-accent` | `#F7A327` | Logo pin icon |
| `--color-error` | `#D72F33` | Error banner text |
| `--color-error-bg` | `#FEE2E1` | Error banner background |
| `--color-bg-page-gray` | `#CFCFCF` | Forgot Password / Verify OTP panel background |
| `--color-text-primary` | `#1A1A1A` | "Login Now" / "Register Now" titles |
| `--color-text-secondary` | `#666666` | Subtitle + tagline text |

These replace an earlier version of this file that used the written §E1 doc
token values, which didn't actually match the finalized mockups.

## Forgot Password / Verify OTP is a popup, not a page

Both screens open as a **plain white card floating over a dimmed backdrop
on top of the Login page** (`js/modal.js` + `js/views/authPopup.js`) — not
a separate routed page, and not the gray/teal split-background "framed
panel" treatment from an earlier version of this file (that turned out to
just be how the original design file presented the screen in isolation for
handoff, not the intended in-app look; the actual popup is just the plain
card, same as the reference popup screenshots):

- Login → "Forgot Password?" → popup opens (Login page stays visible,
  dimmed, underneath)
- "Send OTP" swaps the popup's content to the Verify OTP step, in place —
  same popup, no page navigation
- "← Back" on Verify OTP swaps back to the Forgot Password step
- "Cancel", or clicking the dimmed backdrop, closes the popup back to plain
  Login

Register is unaffected — it's still a full page (`#/register`), matching
its own edge-to-edge mockup treatment.


**Not covered here** (out of scope per this request): the Operator/Admin
dashboard shells, sidebar nav, fleet map panel, and the rest of §E4 — those
are a different catalog for a different set of screens.

## How to run

**Just open `index.html` in your browser.** Double-click it, or drag it into
a browser tab. There's no build step and no local server needed — every
script is a plain `<script src="...">` (no ES modules, no bundler), and the
font/logo/CSS are all local files, so it works straight off the filesystem
(`file://`).

If your browser or setup ever complains about loading local files (some
strict configurations block certain `file://` requests), serve the folder
instead — from *inside* this folder, either:

```bash
# Python (usually already installed)
python3 -m http.server 8000
# then open http://localhost:8000

# or Node, if you have it
npx serve .
```

## Click-through path

- `#/login` (default) → click "Forgot Password?" → popup opens over Login →
  "Send OTP" → popup content swaps to Verify OTP (same popup)
- `#/login` → "Create an account" / "Register" → `#/register` (real page nav)
- In the popup, typing the exact email `Test@account.com` and submitting
  shows the "This email is not registered" error state from `Web_Error.png`
  — anything else "succeeds" and advances to the Verify OTP step. This is a
  preview-only demo shortcut (see the comment in `js/views/authPopup.js`),
  not real validation.

## What's mocked vs. real

Every view's `init()` wires its buttons to plain functions, and every place
that should eventually hit the FastAPI backend is marked
`// TODO(Francis): ...` with the exact F7 (`js/api_client.js` /
`authModule`) method it should call instead, e.g.:

```js
// TODO(Francis): replace with:
//   authModule.login(usernameOrEmail, password)
//     .then(() => location.href = '/operator/' or '/admin/' per role)
//     .catch(() => showError('login-error'));
console.log('[preview] login submit', { usernameOrEmail, password, rememberMe });
```

To wire it up for real: build the real `js/api_client.js` / `js/auth.js`
(F7), and swap each `console.log(...)` / `alert(...)` placeholder for the
real `fetch()` call. Nothing in `js/components.js` or the CSS needs to
change to do that.

## Known deviations worth a quick gut-check

The button radius in the mockups (~12px) is more rounded than a sharp
rectangle but noticeably less rounded than the pill-shaped buttons in the
Flutter mobile mockups — `--radius-button` in `theme.css` follows the web
mockups specifically (the two are allowed to differ). `--color-success` is
still the old §E1 doc value since no green UI element appears in these 4
screens to sample it from — worth a real sample once a screen that uses it
exists.
