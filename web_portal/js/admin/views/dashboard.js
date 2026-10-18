// js/admin/views/dashboard.js
//
// Dashboard: headline stats, newest user accounts, pending operator
// verifications and the system health monitor.

AdminRouter.register('dashboard', {
  title: 'Dashboard',

  mount(el) {
    const RECENT_USERS = 5;
    const VISIBLE_PENDING = 2; // more than this and the list scrolls
    const HEALTH_POLL_MS = 30000;

    // undefined = still loading (skeleton), null = failed to load ("—")
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

    const cardValue = (source, pick) => {
      if (source === undefined) return undefined;
      return source === null ? '—' : pick(source);
    };

    function renderStats() {
      statsEl.innerHTML = AdminUi.statGrid([
        ['Total Users', cardValue(stats, (s) => AdminUi.formatNumber(s.total_users))],
        ['Active Drivers', cardValue(stats, (s) => AdminUi.formatNumber(s.active_drivers))],
        ['Pending Verif.', cardValue(stats, (s) => AdminUi.formatNumber(s.pending_operators))],
        ['System Uptime', cardValue(health, (h) => `${h.uptime_percent}%`)],
      ]);
    }

    function loadStats() {
      AdminApi.userStats()
        .then((s) => { stats = s; }, () => { stats = null; })
        .finally(renderStats);
    }

    function loadUsers() {
      return AdminUi.loadInto(usersEl, () => AdminApi.listUsers({ limit: RECENT_USERS }), (list) => {
        users = list;
        usersEl.innerHTML = AdminUi.usersTable(users, { currentEmail: Session.email });
      });
    }

    function loadPending() {
      return AdminUi.loadInto(pendingEl, () => AdminApi.listOperators('pending'), (list) => {
        pending = list;
        pendingEl.innerHTML = AdminUi.pendingOperatorList(pending);
        fitPending();
      });
    }

    /** Show exactly VISIBLE_PENDING operators; the rest scroll inside the panel. */
    function fitPending() {
      pendingEl.style.maxHeight = '';
      const items = pendingEl.querySelectorAll('.pending-item');
      if (items.length <= VISIBLE_PENDING) return;
      const lastVisible = items[VISIBLE_PENDING - 1].getBoundingClientRect().bottom;
      // A little room under the last item, but less than the list gap so
      // the next item stays hidden until scrolled to.
      pendingEl.style.maxHeight = `${lastVisible - pendingEl.getBoundingClientRect().top + 16}px`;
    }

    function renderHealth(h) {
      health = h;
      renderStats();
      healthEl.innerHTML = AdminUi.healthList(h);
    }

    function loadHealth() {
      AdminUi.loadInto(healthEl, AdminApi.systemHealth, renderHealth).then(() => {
        health ??= null;
        renderStats();
      });
    }

    function refreshAll() {
      loadStats();
      loadUsers();
      loadPending();
    }

    UserActions.bind(usersEl, {
      findUser: (id) => users.find((u) => u.id === id),
      onChanged: refreshAll,
    });
    OperatorReview.bind(pendingEl, {
      findProfile: (id) => pending.find((p) => p.id === id),
      onDone: refreshAll,
    });

    renderStats();
    refreshAll();
    loadHealth();

    // Keep the health monitor live without flashing a loading state.
    const timer = setInterval(() => {
      AdminApi.systemHealth().then(renderHealth).catch(() => {});
    }, HEALTH_POLL_MS);
    // Names can wrap differently at another width, changing item heights.
    window.addEventListener('resize', fitPending);
    return () => {
      clearInterval(timer);
      window.removeEventListener('resize', fitPending);
    };
  },
});
