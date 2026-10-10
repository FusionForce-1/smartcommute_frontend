// js/operator/views/reports.js
//
// Reports: fleet performance (GET /reports/fleet), a per-route summary
// and every commuter feedback report on the operator's routes, with a
// category filter and CSV export.

OperatorRouter.register('reports', {
  title: 'Reports',
  heading: 'Operator Reports',

  mount(el) {
    const esc = AdminUi.escapeHtml;
    const FEEDBACK_LIMIT = 100;
    const CATEGORY_FILTERS = [
      { value: '', label: 'All' },
      ...Object.entries(OperatorUi.FEEDBACK_CATEGORY).map(([value, label]) => ({ value, label })),
    ];

    let routes = [];
    let feedback = [];
    let filter = '';

    el.innerHTML = `
      <div id="rep-revenue"></div>
      <div class="op-page-head"><div><h2>Fleet &amp; Service</h2></div></div>
      <div id="rep-stats"></div>
      <section class="op-card op-card--flush" style="margin-bottom:var(--space-sm);">
        <div class="op-card__head">
          <h3>Route Summary</h3>
          <p class="op-card__sub" style="margin:0;">Service status, fares and assigned vehicles per route.</p>
        </div>
        <div id="rep-routes"></div>
      </section>
      <section class="op-card op-card--flush">
        <div class="op-card__head">
          <div class="op-page-head" style="margin:0;">
            <div>
              <h3>Commuter Feedback</h3>
              <p class="op-card__sub" style="margin:0;">Reports commuters filed about your routes, newest first.</p>
            </div>
            <button type="button" class="btn-sm btn-sm--teal" id="rep-export" disabled>Export CSV</button>
          </div>
          <div class="op-breakdown" id="rep-filters"></div>
        </div>
        <div id="rep-feedback"></div>
      </section>`;

    const statsEl = el.querySelector('#rep-stats');
    const routesEl = el.querySelector('#rep-routes');
    const feedbackEl = el.querySelector('#rep-feedback');
    const filtersEl = el.querySelector('#rep-filters');
    const exportBtn = el.querySelector('#rep-export');

    const routeLabel = (id) => OperatorUi.routeLabels(routes)[id] || 'Unknown route';
    const visibleFeedback = () => (filter ? feedback.filter((f) => f.category === filter) : feedback);

    // ---------- Fleet performance ----------

    function renderStats(report) {
      const pct = (n) => (typeof n === 'number' ? `${n}%` : undefined);
      statsEl.innerHTML = OperatorUi.stats([
        ['Total Vehicles', report?.total_vehicles],
        ['Active Vehicles', report?.active_vehicles, 'green'],
        ['Fleet Uptime', pct(report?.uptime_percent), 'blue'],
        ['GPS Coverage (1 hr)', pct(report?.gps_coverage_percent), 'amber'],
      ]);
    }

    function loadStats() {
      renderStats(null);
      OperatorApi.fleetReport().then(renderStats).catch(() => {
        statsEl.innerHTML = OperatorUi.stats([
          ['Total Vehicles', '—'], ['Active Vehicles', '—'], ['Fleet Uptime', '—'], ['GPS Coverage (1 hr)', '—'],
        ]);
      });
    }

    // ---------- Routes ----------

    function renderRoutes() {
      const rows = routes.length
        ? routes.map((r) => `
            <tr>
              <td class="data-table__name">${esc(r.code)}</td>
              <td>${esc(r.name)}</td>
              <td>${esc(r.terminal_a || '—')} → ${esc(r.terminal_b || '—')}</td>
              <td>${r.is_active ? OperatorUi.chip('Active', 'green') : OperatorUi.chip('Inactive')}</td>
              <td>${r.stop_count}</td>
              <td>${OperatorUi.fare(r.base_fare)}</td>
              <td>${r.vehicle_count}</td>
              <td>${feedback.filter((f) => f.route_id === r.id).length}</td>
            </tr>`).join('')
        : '<tr><td colspan="8" class="data-table__empty">No routes yet.</td></tr>';
      routesEl.innerHTML = `
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr><th>Code</th><th>Name</th><th>Terminals</th><th>Status</th><th>Stops</th><th>Fare</th><th>Vehicles</th><th>Feedback</th></tr>
            </thead>
            <tbody>${rows}</tbody>
          </table>
        </div>`;
    }

    // ---------- Feedback ----------

    function renderFilters() {
      filtersEl.innerHTML = AdminUi.filterChips(CATEGORY_FILTERS, filter);
    }

    function renderFeedback() {
      const list = visibleFeedback();
      exportBtn.disabled = !list.length;
      const rows = list.length
        ? list.map((f) => `
            <tr>
              <td style="white-space:nowrap;">${esc(AdminUi.formatDateTime(f.created_at))}</td>
              <td>${esc(routeLabel(f.route_id))}</td>
              <td>${OperatorUi.chip(OperatorUi.FEEDBACK_CATEGORY[f.category] || f.category, 'blue')}</td>
              <td>${esc(f.message)}</td>
              <td>${AdminUi.statusChip(f.status)}</td>
            </tr>`).join('')
        : `<tr><td colspan="5" class="data-table__empty">${feedback.length ? 'No feedback in this category.' : 'No commuter feedback on your routes yet.'}</td></tr>`;
      feedbackEl.innerHTML = `
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Date</th><th>Route</th><th>Category</th><th>Message</th><th>Status</th></tr></thead>
            <tbody>${rows}</tbody>
          </table>
        </div>`;
    }

    function exportCsv() {
      const cell = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`;
      const lines = [
        ['Date', 'Route', 'Category', 'Message', 'Status'].map(cell).join(','),
        ...visibleFeedback().map((f) => [
          AdminUi.formatDateTime(f.created_at),
          routeLabel(f.route_id),
          OperatorUi.FEEDBACK_CATEGORY[f.category] || f.category,
          f.message,
          f.status,
        ].map(cell).join(',')),
      ];
      const blob = new Blob([`﻿${lines.join('\r\n')}`], { type: 'text/csv;charset=utf-8' });
      const url = URL.createObjectURL(blob);
      const link = Object.assign(document.createElement('a'), {
        href: url,
        download: `smartcommute-feedback-${new Date().toISOString().slice(0, 10)}.csv`,
      });
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
    }

    function loadTables() {
      let loaded = false;
      AdminUi.loadInto(feedbackEl, async () => {
        const [r, f] = await Promise.all([
          OperatorApi.myRoutes(),
          OperatorApi.myFeedback({ limit: FEEDBACK_LIMIT }),
        ]);
        return { r, f };
      }, ({ r, f }) => {
        loaded = true;
        routes = r;
        feedback = f;
        renderRoutes();
        renderFeedback();
      }).then(() => {
        if (!loaded) routesEl.innerHTML = ''; // the error + retry shows under feedback
      });
      routesEl.innerHTML = AdminUi.stateMessage('Loading…');
    }

    filtersEl.addEventListener('click', (e) => {
      const chip = e.target.closest('[data-filter]');
      if (!chip) return;
      filter = chip.dataset.filter;
      renderFilters();
      renderFeedback();
    });
    exportBtn.addEventListener('click', exportCsv);

    RevenueReport.mount(el.querySelector('#rep-revenue'));
    renderFilters();
    loadStats();
    loadTables();
  },
});
