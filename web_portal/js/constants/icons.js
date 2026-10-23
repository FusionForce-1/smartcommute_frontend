// js/constants/icons.js
//
// Single source of truth for every icon used across the Smart Commute
// Leaflet.js web portal (Operator + Admin). Use ICONS wherever an icon
// name is needed instead of hardcoding a Lucide icon string in each
// page/component — that way an icon (or the whole icon set) only ever
// has to be changed in one place.
//
// Loaded as a plain global-scope script (no ES module `import`/`export`)
// so it matches components.js and the rest of the project — make sure
// this file is included in index.html BEFORE components.js, e.g.:
//   <script src="js/constants/icons.js"></script>
//   <script src="js/components.js"></script>
//
// Usage:
//   el.innerHTML = `<i data-lucide="${ICONS.email}"></i>`;
//
// Values are Lucide icon names (https://lucide.dev/icons/) — swap the
// whole file for a different icon set without touching any page.

const ICONS = Object.freeze({
  // ---- Auth (Login / Register / Forgot Password / Verify OTP) ----
  google: 'chrome',            // Google "G" logo is served as its own asset (see GOOGLE_LOGO_SRC below); this is a placeholder slot only
  email: 'mail',
  passwordVisible: 'eye',
  passwordHidden: 'eye-off',
  checkboxOn: 'check-square',
  checkboxOff: 'square',
  forgotKey: 'key-round',
  otpEnvelope: 'mail-check',
  back: 'chevron-left',
  close: 'x',

  // ---- Sidebar / navbar chrome ----
  bell: 'bell',
  avatar: 'user-circle',
  logout: 'log-out',
  sidebarNav: 'menu',
  settings: 'settings',

  // ---- Admin sidebar ----
  navDashboard: 'layout-grid',
  navUsers: 'users',
  navVerification: 'circle-check',
  navSystemHealth: 'bell',
  navReports: 'file-text',
  navConfig: 'settings',
  navLogout: 'log-out',
  navHelp: 'circle-help',

  // ---- Operator sidebar (Log Out reuses navLogout) ----
  navFleetMap: 'map',
  navRoutes: 'route',
  navVehicles: 'bus',
  navDrivers: 'id-card',
  navAnnouncements: 'megaphone',
  navOperatorReports: 'bar-chart-3',
  navProfile: 'user-round',
  navSettings: 'settings',

  // ---- Fleet / vehicles / routes ----
  plate: 'car-front',
  route: 'route',
  fleetMap: 'map',
  statusActive: 'check-circle-2',
  statusCongested: 'triangle-alert',
  statusSuspended: 'ban',

  // ---- Admin tables / reports ----
  auditLog: 'clipboard-list',
  users: 'users',
  reports: 'bar-chart-3',
  announcement: 'megaphone',
  exportCsv: 'download',

  // ---- Toast / modal ----
  toastSuccess: 'check-circle',
  toastError: 'alert-circle',
  toastInfo: 'info',
  modalConfirm: 'check',
  modalCancel: 'x-circle',
});

// Google's "G" logo is brand asset, not a Lucide glyph — kept alongside
// ICONS so every page pulls it from one place too.
// Relative (no leading slash) so it resolves under any server root, e.g.
// Live Server at /smartcommute_frontend/web_portal/.
const GOOGLE_LOGO_SRC = 'assets/icons/google-logo.svg';