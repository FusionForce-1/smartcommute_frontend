// Operator app
// Operator app
const OperatorApp = (() => {
  const LOGIN_URL = '../index.html#/login';

  const NAV_ITEMS = [
    { route: 'fleet', label: 'Fleet Map', icon: 'navFleetMap' },
    { route: 'playback', label: 'Playback', icon: 'navPlayback' },
    { route: 'routes', label: 'Routes & Stops', icon: 'navRoutes' },
    { route: 'vehicles', label: 'Vehicles', icon: 'navVehicles' },
    { route: 'drivers', label: 'Drivers', icon: 'navDrivers' },
    { route: 'driver-reports', label: 'Driver Reports', icon: 'navDriverReports', badgeId: 'op-reports-badge' },
    { route: 'announcements', label: 'Announcements', icon: 'navAnnouncements' },
    { route: 'reports', label: 'Reports', icon: 'navOperatorReports' },
    { route: 'profile', label: 'Profile', icon: 'navProfile' },
    { route: 'settings', label: 'Settings', icon: 'navSettings' },
  ];

  const HELP_TOPICS = [
    ['Fleet Map', 'Live vehicle positions on the map, plus your active vehicles, route alerts and recent commuter feedback.'],
    ['Playback', 'Replay where a vehicle went in the last 7 days, at up to 60× speed.'],
    ['Routes & Stops', 'Add and edit routes, fares and stops. New routes start inactive until you are ready to begin service.'],
    ['Vehicles', 'Register vehicles, assign them to routes and drivers, and manage their GPS trackers.'],
    ['Drivers', 'Add a driver by scanning both sides of their license, then hand them the app login shown once after saving. You also start and end each shift here; the driver app follows.'],
    ['Driver Reports', 'Emergencies, breakdowns, delays and other reports your drivers send from the app, with the vehicle, route and location when they are on shift. The red badge counts unread ones; new reports pop up on any page within 30 seconds.'],
    ['Announcements', 'Send service alerts, schedule changes and promotions to the commuters who ride your routes.'],
    ['Reports', 'Fleet and service figures, and revenue from the daily remittances you record for each vehicle.'],
    ['Subscription (top-right button)', 'Your first 3 months are free. After that the plan is ₱1,000 a year, paid with PayPal, for unlimited vehicles.'],
    ['Profile & Settings', 'Update your company details, change your password, choose whether to get emails, and turn two-factor authentication on or off.'],
  ];

  // Redirect to login
  function redirectToLogin() {
    window.location.replace(LOGIN_URL);
  }

  const PENDING_CLAIM_KEY = 'sc_pending_claim';
  const PENDING_DEVICE_KEY = 'sc_pending_claim_device';

  // Remember claim from URL
  function rememberClaimFromUrl() {
    const params = new URLSearchParams(location.search);
    if (!params.has('claim')) return;
    try {
      sessionStorage.setItem(PENDING_CLAIM_KEY, params.get('claim'));
      sessionStorage.setItem(PENDING_DEVICE_KEY, params.get('device') || '');
    } catch {  }
    params.delete('claim');
    params.delete('device');
    const query = params.toString();
    history.replaceState(null, '', `${location.pathname}${query ? `?${query}` : ''}#/vehicles`);
  }

  // Take pending claim
  function takePendingClaim() {
    try {
      const code = sessionStorage.getItem(PENDING_CLAIM_KEY);
      const device = sessionStorage.getItem(PENDING_DEVICE_KEY);
      sessionStorage.removeItem(PENDING_CLAIM_KEY);
      sessionStorage.removeItem(PENDING_DEVICE_KEY);
      return code ? { code, device } : null;
    } catch {
      return null;
    }
  }

  // Nav link
  function navLink({ route, label, icon, badgeId }) {
    return `
      <a href="#/${route}" class="admin-nav__link" data-route="${route}">
        ${iconMarkup(icon)}<span class="admin-nav__label">${label}</span>
        ${badgeId ? `<span class="op-nav-badge" id="${badgeId}" title="Unread" hidden></span>` : ''}
      </a>`;
  }

  // Nav button
  function navButton(id, label, icon) {
    return `
      <button type="button" class="admin-nav__link" id="${id}">
        ${iconMarkup(icon)}<span class="admin-nav__label">${label}</span>
      </button>`;
  }

  // Render sidebar
  function renderSidebar() {
    document.getElementById('op-nav').innerHTML = NAV_ITEMS.map(navLink).join('');
    document.getElementById('op-nav-footer').innerHTML =
      navButton('op-logout', 'Log Out', 'navLogout') +
      navButton('op-help', 'Help', 'navHelp');

    document.getElementById('op-logout').addEventListener('click', async () => {
      await AuthModule.logout();
      redirectToLogin();
    });
    document.getElementById('op-help').addEventListener('click', openHelp);
  }

  // Open help
  function openHelp() {
    AdminModal.open({
      title: 'Help',
      size: 'sm',
      body: HELP_TOPICS
        .map(([topic, text]) => `<p class="modal-text"><strong>${topic}:</strong> ${text}</p>`)
        .join(''),
    });
  }

  // On route change
  function onRouteChange(activeRoute, view) {
    document.getElementById('op-title').textContent = view.heading || view.title;
    document.querySelectorAll('#op-nav [data-route]').forEach((link) => {
      const isActive = link.dataset.route === activeRoute;
      link.classList.toggle('is-active', isActive);
      if (isActive) link.setAttribute('aria-current', 'page');
      else link.removeAttribute('aria-current');
    });
  }

  // Render company
  function renderCompany({ company_name }) {
    document.getElementById('op-company').textContent = company_name || '';
    document.getElementById('op-account').hidden = !company_name;
  }

  // Load profile
  async function loadProfile() {
    window.addEventListener('profile:updated', (e) => renderCompany(e.detail));
    const notice = document.getElementById('op-notice');
    try {
      const profile = await OperatorApi.profile();
      renderCompany(profile);
      if (!profile.is_verified) {
        notice.textContent =
          'Your operator account is waiting for admin verification. ' +
          'Fleet, route and announcement tools unlock once an admin approves it.';
        notice.hidden = false;
      }
    } catch (err) {
      if (err.statusCode === 404) {
        notice.textContent = 'Your company profile is missing. Sign out and sign in again to complete it.';
        notice.hidden = false;
      }
    }
  }

  // Start operator app
  function start() {
    rememberClaimFromUrl();
    if (!Session.accessToken || Session.role !== 'operator') {
      redirectToLogin();
      return;
    }

    window.addEventListener('session:expired', redirectToLogin);
    IdleTimeout.start(async () => {
      await AuthModule.logout();
      redirectToLogin();
    });
    renderSidebar();
    loadProfile();
    OperatorRouter.start(onRouteChange);
    DriverReportAlerts.start();
    document.getElementById('op-subscription').addEventListener('click', OperatorSubscription.open);
    if (new URLSearchParams(location.search).has('paypal')) OperatorSubscription.open();
    const claim = takePendingClaim();
    if (claim) TrackerSetup.claimFromLabel(claim.code, claim.device);
  }

  return { start };
})();

OperatorApp.start();
