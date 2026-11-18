// Admin users view
AdminRouter.register('users', {
  title: 'Users',

  // Mount the view
  mount(el) {
    const PAGE_SIZE = 50;
    const ROLE_FILTERS = [
      { value: '', label: 'All' },
      { value: 'admin', label: 'Admin' },
      { value: 'operator', label: 'Operator' },
      { value: 'driver', label: 'Driver' },
      { value: 'commuter', label: 'Commuter' },
    ];

    let role = '';
    let users = [];
    let hasMore = false;

    el.innerHTML = `
      <div id="users-stats">${AdminUi.statGrid([['Total Users'], ['Commuters'], ['Drivers'], ['Operators']])}</div>
      ${AdminUi.panel({
        title: 'All User Accounts',
        subtitle: 'Search, review, and manage access for every account.',
        bodyId: 'users-table',
        bodyClass: 'panel__body--flush',
        panelClass: 'panel--fill',
        between: `
          <div class="filter-bar">
            <span class="filter-bar__label">Filter by role</span>
            <div class="filter-bar__chips" id="users-filters"></div>
          </div>`,
      })}`;

    const statsEl = el.querySelector('#users-stats');
    const filtersEl = el.querySelector('#users-filters');
    const tableEl = el.querySelector('#users-table');

    // Load stats
    function loadStats() {
      AdminApi.userStats()
        .then((s) => statsEl.innerHTML = AdminUi.statGrid([
          ['Total Users', AdminUi.formatNumber(s.total_users)],
          ['Commuters', AdminUi.formatNumber(s.by_role.commuter)],
          ['Drivers', AdminUi.formatNumber(s.by_role.driver)],
          ['Operators', AdminUi.formatNumber(s.by_role.operator)],
        ]))
        .catch(() => statsEl.innerHTML = AdminUi.statGrid([
          ['Total Users', '—'], ['Commuters', '—'], ['Drivers', '—'], ['Operators', '—'],
        ]));
    }

    // Render filters
    function renderFilters() {
      filtersEl.innerHTML = AdminUi.filterChips(ROLE_FILTERS, role, 'role');
    }

    // Render table
    function renderTable() {
      tableEl.innerHTML = AdminUi.usersTable(users, { firstColumn: 'User', currentEmail: Session.email })
        + (hasMore ? '<div class="load-more"><button type="button" class="btn-sm" data-load-more>Load more</button></div>' : '');
    }

    // Load first page
    function loadFirstPage() {
      AdminUi.loadInto(tableEl, () => AdminApi.listUsers({ role, limit: PAGE_SIZE }), (page) => {
        users = page;
        hasMore = page.length === PAGE_SIZE;
        renderTable();
      });
    }

    // Load next page
    async function loadNextPage(button) {
      button.disabled = true;
      try {
        const page = await AdminApi.listUsers({ role, skip: users.length, limit: PAGE_SIZE });
        users = users.concat(page);
        hasMore = page.length === PAGE_SIZE;
        renderTable();
      } catch (err) {
        button.disabled = false;
        AdminUi.toast(err.message, { error: true });
      }
    }

    filtersEl.addEventListener('click', (e) => {
      const chip = e.target.closest('[data-role]');
      if (!chip || chip.dataset.role === role) return;
      role = chip.dataset.role;
      renderFilters();
      loadFirstPage();
    });

    tableEl.addEventListener('click', (e) => {
      const button = e.target.closest('[data-load-more]');
      if (button) loadNextPage(button);
    });

    UserActions.bind(tableEl, {
      // Find user
      findUser: (id) => users.find((u) => u.id === id),
      onChanged: () => {
        loadStats();
        loadFirstPage();
      },
    });

    renderFilters();
    loadStats();
    loadFirstPage();
  },
});
