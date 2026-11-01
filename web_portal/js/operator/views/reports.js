// js/operator/views/reports.js
//
// Reports: revenue, fleet performance (GET /reports/fleet), a per-route
// summary, and Driver Reviews — what commuters said about the drivers of
// this operator's jeeps (GET /reviews/operator; commuters stay anonymous),
// by driver, for a period (last 3 months by default) and in an order.

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
      </section>
      <section class="op-card op-card--flush" style="margin-top:var(--space-sm);">
        <div class="op-card__head" style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px;flex-wrap:wrap;">
          <div>
            <h3>Driver Reviews</h3>
            <p class="op-card__sub" style="margin:0;">Ratings commuters gave the drivers of your PUVs. Commuters stay anonymous.</p>
          </div>
          <div style="display:flex;gap:8px;flex-wrap:wrap;">
            <select id="rep-review-driver" aria-label="Filter reviews by driver" style="min-width:200px;">
              <option value="">All drivers</option>
            </select>
            <select id="rep-review-days" aria-label="Reviews from">
              <option value="7">Last 7 days</option>
              <option value="30">Last 30 days</option>
              <option value="90" selected>Last 3 months</option>
              <option value="180">Last 6 months</option>
              <option value="365">Last 12 months</option>
              <option value="">All time</option>
            </select>
            <select id="rep-review-sort" aria-label="Sort reviews">
              <option value="recent" selected>Most recent</option>
              <option value="oldest">Oldest first</option>
              <option value="highest">Highest rating</option>
              <option value="lowest">Lowest rating</option>
            </select>
          </div>
        </div>
        <div id="rep-review-summary" style="padding:0 var(--space-sm);"></div>
        <div id="rep-reviews"></div>
      </section>`;

    const statsEl = el.querySelector('#rep-stats');
    const routesEl = el.querySelector('#rep-routes');
    const reviewSummaryEl = el.querySelector('#rep-review-summary');
    const reviewsEl = el.querySelector('#rep-reviews');
    const driverSelect = el.querySelector('#rep-review-driver');
    const daysSelect = el.querySelector('#rep-review-days');
    const sortSelect = el.querySelector('#rep-review-sort');

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

    // ---------- Driver reviews ----------

    const TAGS = {
      safe_driving: ['Safe driving', true], friendly: ['Friendly', true], clean: ['Clean PUV', true],
      on_time: ['On time', true], honest_fare: ['Honest fare', true],
      reckless_driving: ['Reckless driving', false], rude: ['Rude', false], overcharging: ['Overcharging', false],
      overloading: ['Overloading', false], late: ['Long wait / late', false], dirty: ['Dirty PUV', false],
    };
    const tagChip = (key, count) => {
      const [label, good] = TAGS[key] || [key.replace(/_/g, ' '), true];
      return OperatorUi.chip(count ? `${label} ×${count}` : label, good ? 'green' : 'red');
    };
    const stars = (n) => `<span style="color:#F5A623;letter-spacing:1px;" aria-label="${n} of 5 stars">${'★'.repeat(Math.round(n))}${'☆'.repeat(5 - Math.round(n))}</span>`;
    const PERIOD = { 7: 'in the last 7 days', 30: 'in the last 30 days', 90: 'in the last 3 months', 180: 'in the last 6 months', 365: 'in the last 12 months' };

    function renderReviewSummary(data) {
      if (!data.total) {
        reviewSummaryEl.innerHTML = '';
        return;
      }
      // The API always sends every driver's summary (it also fills the
      // dropdown), so narrow the cards and the headline to the pick here.
      const picked = driverSelect.value;
      const shown = picked ? data.summary.filter((s) => (s.driver_id || 'none') === picked) : data.summary;
      const headline = picked
        ? (shown[0] ? { label: shown[0].driver_name, average: shown[0].average, total: shown[0].count } : null)
        : { label: 'Overall', average: data.average, total: data.total };
      if (!headline) {
        reviewSummaryEl.innerHTML = '';
        return;
      }
      const cards = shown.map((s) => `
        <div class="op-card" style="margin:0;padding:12px;">
          <strong>${esc(s.driver_name)}</strong>
          <div style="margin:4px 0;">${stars(s.average)} <strong>${s.average.toFixed(1)}</strong>
            <span class="op-card__sub">· ${s.count} review${s.count === 1 ? '' : 's'}</span></div>
          <div style="display:flex;gap:4px;flex-wrap:wrap;">
            ${Object.entries(s.tag_counts).slice(0, 4).map(([k, n]) => tagChip(k, n)).join('')}
          </div>
        </div>`).join('');
      reviewSummaryEl.innerHTML = `
        <p class="modal-text" style="margin:8px 0;">${esc(headline.label)} ${stars(headline.average)} <strong>${headline.average.toFixed(1)}</strong>
          from ${headline.total} review${headline.total === 1 ? '' : 's'} ${esc(PERIOD[daysSelect.value] || 'in total')}</p>
        <div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px;margin-bottom:12px;">${cards}</div>`;
    }

    /** The drivers reviewed in the period, keeping the current pick even if it has none now. */
    function renderDriverOptions(summary) {
      const picked = driverSelect.value;
      const options = summary.map((s) =>
        `<option value="${esc(s.driver_id || 'none')}">${esc(s.driver_name)} (${s.count})</option>`);
      const pickedListed = !picked || summary.some((s) => (s.driver_id || 'none') === picked);
      const keep = pickedListed ? '' : `<option value="${esc(picked)}">${esc(driverSelect.selectedOptions[0]?.textContent.replace(/ \(\d+\)$/, '') || 'Driver')} (0)</option>`;
      driverSelect.innerHTML = `<option value="">All drivers</option>${options.join('')}${keep}`;
      driverSelect.value = picked;
    }

    function renderReviews(data) {
      renderDriverOptions(data.summary);
      renderReviewSummary(data);
      const rows = data.reviews.length
        ? data.reviews.map((r) => `
            <tr>
              <td>${esc(AdminUi.formatDate(r.created_at))}</td>
              <td class="data-table__name">${esc(r.driver_name || '—')}</td>
              <td>${esc(r.plate_number || '—')}</td>
              <td>${esc(r.route_code || '—')}</td>
              <td style="white-space:nowrap;">${stars(r.rating)}</td>
              <td><div style="display:flex;gap:4px;flex-wrap:wrap;">${r.tags.map((t) => tagChip(t)).join('') || '—'}</div></td>
              <td>${esc(r.comment || '—')}</td>
            </tr>`).join('')
        : `<tr><td colspan="7" class="data-table__empty">${daysSelect.value
          ? `No reviews ${esc(PERIOD[daysSelect.value])}. Pick a longer period to see older ones.`
          : 'No reviews of your drivers yet. Commuters can rate a ride from their Profile → Rate Your Ride.'}</td></tr>`;
      reviewsEl.innerHTML = `
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Date</th><th>Driver</th><th>Vehicle</th><th>Route</th><th>Rating</th><th>Tags</th><th>Comment</th></tr></thead>
            <tbody>${rows}</tbody>
          </table>
        </div>`;
    }

    function loadReviews() {
      const query = { driverId: driverSelect.value, days: daysSelect.value, sort: sortSelect.value };
      AdminUi.loadInto(reviewsEl, () => OperatorApi.driverReviews(query), renderReviews);
    }
    [driverSelect, daysSelect, sortSelect].forEach((select) => select.addEventListener('change', loadReviews));

    RevenueReport.mount(el.querySelector('#rep-revenue'));
    loadStats();
    loadRoutes();
    loadReviews();
  },
});
