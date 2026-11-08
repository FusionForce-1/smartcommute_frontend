# Smart Commute — Web Portal

Browser portal for **transport operators** and **system administrators**. It is
plain HTML, CSS, and JavaScript with Leaflet maps: no framework, no build step,
no `npm install`.

| Page | Who | What |
|---|---|---|
| `index.html` | everyone | Login, operator registration (email or Google), password recovery by OTP, sign-in codes |
| `operator/operator.html` | transport operators | Fleet Map, Playback, Routes & Stops, Vehicles and GPS trackers, Drivers and shifts, Driver Reports, Announcements, Reports, Profile, Settings, Subscription |
| `admin/admin.html` | system administrators | Dashboard, Users, Verification of operators, System Health, Reports (audit log), Config |

After login, the portal opens the page that matches the account's role.

## Layout

```
web_portal/
├── index.html, operator/, admin/   pages
├── js/
│   ├── config.js                   backend address and Google client ID
│   ├── services/                   API client, session, auth, Google sign-in
│   ├── views/                      login, register, password-recovery pop-up
│   ├── operator/  admin/           each portal's app, router, API calls and views
│   └── constants/, legal.js        icons, User Agreement and Privacy Policy text
├── css/, assets/                   styles, fonts, icons, images
├── data/cebu_landmarks.json        landmark search list (tools/build_landmarks.py)
└── firmware/                       GPS tracker firmware releases (tools/release_firmware.py)
```

## Configuration

`js/config.js` picks the backend by itself: opened from `localhost` or
`127.0.0.1`, the portal calls the local backend at `http://localhost:8000`;
anywhere else (e.g. on Vercel), it calls `https://smart-commute-backend.onrender.com`.
`GOOGLE_CLIENT_ID` there must match the backend's `GOOGLE_CLIENT_ID`.

## Run locally

Serve the folder over HTTP (opening the files directly breaks Google Sign-In and
API calls), for example with the VS Code Live Server extension or:

```bash
cd web_portal
python -m http.server 5500
```

Then open `http://127.0.0.1:5500`. The address must be listed in the backend's
`ALLOWED_ORIGINS` and among the *Authorized JavaScript origins* of the Google
OAuth client.

## Deploy

The portal is deployed to Vercel as a static site (root directory `web_portal`,
no build command): `https://smartcommutefrontend-webportal.vercel.app`. The same
site serves `firmware/manifest.json`, which the *Install tracker firmware*
button uses to flash trackers over USB from Chrome or Edge, and
`firmware/latest.json`, which trackers check for over-the-air updates.

To publish new tracker firmware, run `python tools/release_firmware.py` in the
backend repository (it writes into `firmware/`), then commit and redeploy this
portal.
