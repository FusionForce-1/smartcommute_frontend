// Admin verification view
AdminRouter.register('verification', {
  title: 'Verification',

  // Mount the view
  mount(el) {
    const STATUS_FILTERS = [
      { value: '', label: 'All' },
      { value: 'pending', label: 'Pending' },
      { value: 'verified', label: 'Verified' },
      { value: 'declined', label: 'Declined' },
    ];

    let filter = '';
    let profiles = [];

    el.innerHTML = `
      <div id="verif-stats">${AdminUi.statGrid([['Pending'], ['Verified'], ['Declined'], ['Total Operators']])}</div>
      ${AdminUi.panel({
        title: 'Operator Registrations',
        subtitle: 'Review company details, then approve or decline each operator.',
        bodyId: 'verif-table',
        bodyClass: 'panel__body--flush',
        panelClass: 'panel--fill',
        between: `
          <div class="filter-bar">
            <span class="filter-bar__label">Filter by status</span>
            <div class="filter-bar__chips" id="verif-filters"></div>
          </div>`,
      })}`;

    const statsEl = el.querySelector('#verif-stats');
    const filtersEl = el.querySelector('#verif-filters');
    const tableEl = el.querySelector('#verif-table');
    const esc = AdminUi.escapeHtml;

    // Count by
    function countBy(status) {
      return profiles.filter((p) => p.status === status).length;
    }

    // Render stats
    function renderStats() {
      statsEl.innerHTML = AdminUi.statGrid([
        ['Pending', countBy('pending')],
        ['Verified', countBy('verified')],
        ['Declined', countBy('declined')],
        ['Total Operators', profiles.length],
      ]);
    }

    // Render table
    function renderTable() {
      const visible = filter ? profiles.filter((p) => p.status === filter) : profiles;
      const rows = visible.length
        ? visible.map((p) => `
            <tr>
              <td class="data-table__name">${esc(p.company_name)}</td>
              <td>${esc(p.full_name || '—')}</td>
              <td>${esc(p.email || '—')}</td>
              <td>${esc(p.contact_number || '—')}</td>
              <td>${esc(p.franchise_number || '—')}</td>
              <td>${AdminUi.statusChip(p.status)}</td>
              <td>
                <button type="button" class="btn-sm btn-sm--teal" data-action="review-operator" data-id="${p.id}">
                  ${p.status === 'pending' ? 'Verify' : 'View'}
                </button>
              </td>
            </tr>`).join('')
        : '<tr><td colspan="7" class="data-table__empty">No operator registrations here.</td></tr>';

      tableEl.innerHTML = `
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr><th>Company</th><th>Owner</th><th>Email</th><th>Contact</th><th>Franchise No.</th><th>Status</th><th>Action</th></tr>
            </thead>
            <tbody>${rows}</tbody>
          </table>
        </div>`;
    }

    // Render filters
    function renderFilters() {
      filtersEl.innerHTML = AdminUi.filterChips(STATUS_FILTERS, filter);
    }

    // Load verification
    function load() {
      AdminUi.loadInto(tableEl, () => AdminApi.listOperators(), (list) => {
        profiles = list;
        renderStats();
        renderTable();
      });
    }

    filtersEl.addEventListener('click', (e) => {
      const chip = e.target.closest('[data-filter]');
      if (!chip) return;
      filter = chip.dataset.filter;
      renderFilters();
      renderTable();
    });

    OperatorReview.bind(tableEl, {
      // Find profile
      findProfile: (id) => profiles.find((p) => p.id === id),
      onDone: load,
    });

    renderFilters();
    load();
  },
});
