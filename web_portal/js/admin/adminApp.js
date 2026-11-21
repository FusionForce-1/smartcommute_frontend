// Admin app
// Admin app
const AdminApp = (() => {
  const LOGIN_URL = '../index.html#/login';

  const NAV_ITEMS = [
    { route: 'dashboard', label: 'Dashboard', icon: 'navDashboard' },
    { route: 'users', label: 'Users', icon: 'navUsers' },
    { route: 'verification', label: 'Verification', icon: 'navVerification' },
    { route: 'system-health', label: 'System Health', icon: 'navSystemHealth' },
    { route: 'reports', label: 'Reports', icon: 'navReports' },
    { route: 'config', label: 'Config', icon: 'navConfig' },
  ];

  const HELP_TOPICS = [
    ['Dashboard', 'A quick overview: user totals, newest accounts, operators waiting for verification and live service status.'],
    ['Users', 'Filter accounts by role. Edit changes a user\'s name, role or status; Delete removes their access.'],
    ['Verification', 'Click Verify on an operator to review their company details, then Approve or Decline.'],
    ['System Health', 'Live status of the API, database, GPS and auth services, refreshed every 30 seconds.'],
    ['Config', 'Change sign-in, GPS, plan, message and trip planner limits; saved changes apply right away. Server Setup shows what is set on the server, and Send test email checks that it can deliver mail.'],
  ];

  // Redirect to login
  function redirectToLogin() {
    window.location.replace(LOGIN_URL);
  }

  // Nav link
  function navLink({ route, label, icon }) {
    return `
      <a href="#/${route}" class="admin-nav__link" data-route="${route}">
        ${iconMarkup(icon)}<span class="admin-nav__label">${label}</span>
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
    document.getElementById('admin-nav').innerHTML = NAV_ITEMS.map(navLink).join('');
    document.getElementById('admin-nav-footer').innerHTML =
      navButton('admin-logout', 'Log Out', 'navLogout') + navButton('admin-help', 'Help', 'navHelp');

    document.getElementById('admin-logout').addEventListener('click', async () => {
      await AuthModule.logout();
      redirectToLogin();
    });
    document.getElementById('admin-help').addEventListener('click', openHelp);
  }

  // Highlight nav
  function highlightNav(activeRoute) {
    document.querySelectorAll('#admin-nav [data-route]').forEach((link) => {
      const isActive = link.dataset.route === activeRoute;
      link.classList.toggle('is-active', isActive);
      if (isActive) link.setAttribute('aria-current', 'page');
      else link.removeAttribute('aria-current');
    });
  }

  // Load account
  async function loadAccount() {
    try {
      const admins = await AdminApi.listUsers({ role: 'admin', limit: 200 });
      const me = admins.find((u) => u.email === Session.email);
      if (!me?.name) return;
      document.getElementById('admin-name').textContent = me.name;
      document.getElementById('admin-account').hidden = false;
    } catch {
    }
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

  // Start admin app
  function start() {
    if (!Session.accessToken || Session.role !== 'admin') {
      redirectToLogin();
      return;
    }

    window.addEventListener('session:expired', redirectToLogin);
    IdleTimeout.start(async () => {
      await AuthModule.logout();
      redirectToLogin();
    });
    document.getElementById('admin-email').textContent = Session.email;
    renderSidebar();
    loadAccount();
    AdminRouter.start(highlightNav);
  }

  return { start };
})();

AdminApp.start();
