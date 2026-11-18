// Admin dashboard view
AdminRouter.register('dashboard', {
  title: 'Dashboard',

  // Mount the view
  mount(el) {
    const RECENT_USERS = 5;
    const VISIBLE_PENDING = 2;
    const HEALTH_POLL_MS = 30000;

    let stats;
    let health;
    let users = [];
    let pending = [];

    el.innerHTML = `
      <div id="dash-stats"></div>
      <div class="panel-grid">
        ${AdminUi.panel({ title: 'User Accounts', bodyId: 'dash-users', panelClass: 'panel--fill' })}
        <div class="panel-stack">
          ${AdminUi.panel({ title: 'Pending Operator Verification', bodyId: 'dash-pending', bodyClass: 'panel__body--scroll' })}
          ${AdminUi.panel({ title: 'System Health Monitor', bodyId: 'dash-health' })}
        </div>
      </div>`;

    const statsEl = el.querySelector('#dash-stats');
    const usersEl = el.querySelector('#dash-users');
    const pendingEl = el.querySelector('#dash-pending');
    const healthEl = el.querySelector('#dash-health');

    // Card value
    const cardValue = (source, pick) => {
      if (source === undefined) return undefined;
      return source === null ? '—' : pick(source);
    };

    // Render stats
    function renderStats() {
      statsEl.innerHTML = AdminUi.statGrid([
        ['Total Users', cardValue(stats, (s) => AdminUi.formatNumber(s.total_users))],
        ['Active Drivers', cardValue(stats, (s) => AdminUi.formatNumber(s.active_drivers))],
        ['Pending Verif.', cardValue(stats, (s) => AdminUi.formatNumber(s.pending_operators))],
        ['System Uptime', cardValue(health, (h) => `${h.uptime_percent}%`)],
      ]);
    }

    // Load stats
    function loadStats() {
      AdminApi.userStats()
        .then((s) => { stats = s; }, () => { stats = null; })
        .finally(renderStats);
    }

    // Load users
    function loadUsers() {
      return AdminUi.loadInto(usersEl, () => AdminApi.listUsers({ limit: RECENT_USERS }), (list) => {
        users = list;
        usersEl.innerHTML = AdminUi.usersTable(users, { currentEmail: Session.email });
      });
    }

    // Load pending
    function loadPending() {
      return AdminUi.loadInto(pendingEl, () => AdminApi.listOperators('pending'), (list) => {
        pending = list;
        pendingEl.innerHTML = AdminUi.pendingOperatorList(pending);
        fitPending();
      });
    }

    // Fit pending
    function fitPending() {
      pendingEl.style.maxHeight = '';
      const items = pendingEl.querySelectorAll('.pending-item');
      if (items.length <= VISIBLE_PENDING) return;
      const lastVisible = items[VISIBLE_PENDING - 1].getBoundingClientRect().bottom;
      pendingEl.style.maxHeight = `${lastVisible - pendingEl.getBoundingClientRect().top + 16}px`;
    }

    // Render health
    function renderHealth(h) {
      health = h;
      renderStats();
      healthEl.innerHTML = AdminUi.healthList(h);
    }

    // Load health
    function loadHealth() {
      AdminUi.loadInto(healthEl, AdminApi.systemHealth, renderHealth).then(() => {
        health ??= null;
        renderStats();
      });
    }

    // Refresh all
    function refreshAll() {
      loadStats();
      loadUsers();
      loadPending();
    }

    UserActions.bind(usersEl, {
      // Find user
      findUser: (id) => users.find((u) => u.id === id),
      onChanged: refreshAll,
    });
    OperatorReview.bind(pendingEl, {
      // Find profile
      findProfile: (id) => pending.find((p) => p.id === id),
      onDone: refreshAll,
    });

    renderStats();
    refreshAll();
    loadHealth();

    const timer = setInterval(() => {
      AdminApi.systemHealth().then(renderHealth).catch(() => {});
    }, HEALTH_POLL_MS);
    window.addEventListener('resize', fitPending);
    return () => {
      clearInterval(timer);
      window.removeEventListener('resize', fitPending);
    };
  },
});
