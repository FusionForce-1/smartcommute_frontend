// js/operator/operatorApp.js
//
// Operator portal bootstrap: auth guard, sidebar, header, then the router.
// Loaded last so every view has registered itself already.

const OperatorApp = (() => {
  const LOGIN_URL = '../index.html#/login';

  const NAV_ITEMS = [
    { route: 'fleet', label: 'Fleet Map', icon: 'navFleetMap' },
    { route: 'routes', label: 'Routes & Stops', icon: 'navRoutes' },
    { route: 'vehicles', label: 'Vehicles', icon: 'navVehicles' },
    { route: 'drivers', label: 'Drivers', icon: 'navDrivers' },
    { route: 'announcements', label: 'Announcements', icon: 'navAnnouncements' },
    { route: 'reports', label: 'Reports', icon: 'navOperatorReports' },
    { route: 'profile', label: 'Profile', icon: 'navProfile' },
    { route: 'settings', label: 'Settings', icon: 'navSettings' },
  ];

  const HELP_TOPICS = [
    ['Fleet Map', 'Live vehicle positions on the map, plus your active vehicles, route alerts and recent commuter feedback.'],
    ['Routes & Stops', 'Add and edit routes, fares and stops. New routes start inactive until you are ready to begin service.'],
    ['Vehicles', 'Register vehicles, assign them to routes and drivers, and manage their GPS trackers.'],
    ['Drivers', 'Add a driver by scanning both sides of their license, then hand them the app login shown once after saving.'],
    ['Announcements', 'Publish transit alerts to notify commuters and drivers about service changes.'],
    ['Reports', 'Fleet and service figures, and revenue from the daily remittances you record for each vehicle.'],
    ['Subscription (top-right button)', 'Your first 3 months are free. After that the plan is ₱1,000 a year, paid with PayPal, for unlimited vehicles.'],
    ['Profile & Settings', 'Update your company details, and turn two-factor authentication on or off.'],
  ];

  function redirectToLogin() {
    window.location.replace(LOGIN_URL);
  }

  // Same sidebar markup as the admin portal (see adminApp.js), styled by admin.css.
  function navLink({ route, label, icon }) {
    return `
      <a href="#/${route}" class="admin-nav__link" data-route="${route}">
        ${iconMarkup(icon)}<span class="admin-nav__label">${label}</span>
      </a>`;
  }

  function navButton(id, label, icon) {
    return `
      <button type="button" class="admin-nav__link" id="${id}">
        ${iconMarkup(icon)}<span class="admin-nav__label">${label}</span>
      </button>`;
  }

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

  function openHelp() {
    AdminModal.open({
      title: 'Help',
      size: 'sm',
      body: HELP_TOPICS
        .map(([topic, text]) => `<p class="modal-text"><strong>${topic}:</strong> ${text}</p>`)
        .join(''),
    });
  }

  function onRouteChange(activeRoute, view) {
    document.getElementById('op-title').textContent = view.heading || view.title;
    document.querySelectorAll('#op-nav [data-route]').forEach((link) => {
      const isActive = link.dataset.route === activeRoute;
      link.classList.toggle('is-active', isActive);
      if (isActive) link.setAttribute('aria-current', 'page');
      else link.removeAttribute('aria-current');
    });
  }

  function renderCompany({ company_name }) {
    document.getElementById('op-company').textContent = company_name || '';
    document.getElementById('op-account').hidden = !company_name;
  }

  /** Company name in the sidebar, plus a notice while the account awaits verification. */
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

  function start() {
    if (!Session.accessToken || Session.role !== 'operator') {
      redirectToLogin();
      return;
    }

    window.addEventListener('session:expired', redirectToLogin);
    renderSidebar();
    loadProfile();
    OperatorRouter.start(onRouteChange);
    document.getElementById('op-subscription').addEventListener('click', OperatorSubscription.open);
    // Back from PayPal (?paypal=return|cancel): reopen the Subscription popup.
    if (new URLSearchParams(location.search).has('paypal')) OperatorSubscription.open();
  }

  return { start };
})();

OperatorApp.start();
