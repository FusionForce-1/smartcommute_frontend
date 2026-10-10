// js/operator/operatorApp.js
//
// Operator portal bootstrap: auth guard, sidebar, header, then the router.
// Loaded last so every view has registered itself already.

const OperatorApp = (() => {
  const LOGIN_URL = '../index.html#/login';

  const NAV_ITEMS = [
    { route: 'fleet', label: 'Fleet Map' },
    { route: 'routes', label: 'Routes & Stops' },
    { route: 'vehicles', label: 'Vehicles' },
    { route: 'drivers', label: 'Drivers' },
    { route: 'announcements', label: 'Announcements' },
    { route: 'reports', label: 'Reports' },
    { route: 'profile', label: 'Profile' },
    { route: 'settings', label: 'Settings' },
  ];

  function redirectToLogin() {
    window.location.replace(LOGIN_URL);
  }

  function renderSidebar() {
    document.getElementById('op-nav').innerHTML = `
      ${NAV_ITEMS.map(({ route, label }) => `
        <a href="#/${route}" class="op-sidebar__link" data-route="${route}">${label}</a>`).join('')}
      <button type="button" class="op-sidebar__link" id="op-logout">Sign out</button>`;

    document.getElementById('op-logout').addEventListener('click', async () => {
      await AuthModule.logout();
      redirectToLogin();
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

  /** Company name in the sidebar, plus a notice while the account awaits verification. */
  async function loadProfile() {
    window.addEventListener('profile:updated', (e) => {
      document.getElementById('op-company').textContent = e.detail.company_name || '';
    });
    const notice = document.getElementById('op-notice');
    try {
      const profile = await OperatorApi.profile();
      document.getElementById('op-company').textContent = profile.company_name || '';
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
    document.getElementById('op-email').textContent = Session.email;
    renderSidebar();
    loadProfile();
    OperatorRouter.start(onRouteChange);
  }

  return { start };
})();

OperatorApp.start();
