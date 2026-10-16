// js/operator/views/reports.js
//
// Reports: revenue, fleet performance (GET /reports/fleet) and a
// per-route summary.

OperatorRouter.register('reports', {
  title: 'Reports',
  heading: 'Operator Reports',

  mount(el) {
    const esc = AdminUi.escapeHtml;
    let routes = [];

    el.innerHTML = `
      <div id="rep-revenue"></div>
      <div class="op-page-head"><div><h2>Fleet &amp; Service</h2></div></div>
      <div id="rep-stats"></div>
      <section class="op-card op-card--flush">
        <div class="op-card__head">
          <h3>Route Summary</h3>
          <p class="op-card__sub" style="margin:0;">Service status, fares and assigned vehicles per route.</p>
        </div>
        <div id="rep-routes"></div>
      </section>`;

    const statsEl = el.querySelector('#rep-stats');
    const routesEl = el.querySelector('#rep-routes');

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
            </tr>`).join('')
        : '<tr><td colspan="7" class="data-table__empty">No routes yet.</td></tr>';
      routesEl.innerHTML = `
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr><th>Code</th><th>Name</th><th>Terminals</th><th>Status</th><th>Stops</th><th>Fare</th><th>Vehicles</th></tr>
            </thead>
            <tbody>${rows}</tbody>
          </table>
        </div>`;
    }

    function loadRoutes() {
      AdminUi.loadInto(routesEl, OperatorApi.myRoutes, (r) => {
        routes = r;
        renderRoutes();
      });
    }

    RevenueReport.mount(el.querySelector('#rep-revenue'));
    loadStats();
    loadRoutes();
  },
});
