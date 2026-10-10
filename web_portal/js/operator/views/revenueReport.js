// js/operator/views/revenueReport.js
//
// Revenue Report section of the Reports page. Revenue comes from the daily
// remittance log: what each vehicle brought in each day, recorded here.
// Shows period totals, a daily revenue chart, breakdowns by route /
// vehicle / driver, and the log itself (record, edit, delete, export).

const RevenueReport = (() => {
  const esc = AdminUi.escapeHtml;
  const BAR_COLOR = '#1F7FB5'; // validated: lightness band, chroma floor, 3:1 on white
  const RANGES = [
    { value: '7', label: 'Last 7 days' },
    { value: '30', label: 'Last 30 days' },
    { value: 'month', label: 'This month' },
    { value: 'custom', label: 'Custom' },
  ];

  const peso = (n) => `₱${Number(n || 0).toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  const pesoShort = (n) => {
    if (n >= 1e6) return `₱${(n / 1e6).toFixed(1).replace(/\.0$/, '')}M`;
    if (n >= 1e3) return `₱${(n / 1e3).toFixed(1).replace(/\.0$/, '')}k`;
    return `₱${Math.round(n)}`;
  };

  /** Local calendar date as YYYY-MM-DD (the portal is used in Philippine time). */
  const isoDay = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  const todayIso = () => isoDay(new Date());
  const addDays = (iso, n) => {
    const d = new Date(`${iso}T00:00:00`);
    d.setDate(d.getDate() + n);
    return isoDay(d);
  };
  const dayLabel = (iso, opts = { month: 'short', day: 'numeric' }) => new Date(`${iso}T00:00:00`).toLocaleDateString('en-US', opts);

  function rangeFor(value, custom) {
    const today = todayIso();
    if (value === '7') return { start: addDays(today, -6), end: today };
    if (value === 'month') return { start: `${today.slice(0, 8)}01`, end: today };
    if (value === 'custom' && custom.start && custom.end) return { ...custom };
    return { start: addDays(today, -29), end: today };
  }

  // ---------- Chart ----------

  /** Single-series daily column chart as inline SVG, with a hover tooltip. */
  function chartSvg(days) {
    const W = 900;
    const H = 260;
    const pad = { top: 16, right: 12, bottom: 28, left: 56 };
    const plotW = W - pad.left - pad.right;
    const plotH = H - pad.top - pad.bottom;
    const max = Math.max(...days.map((d) => d.amount), 0);

    // Up to 4 "nice" ticks.
    const rawStep = max > 0 ? max / 3 : 1;
    const mag = 10 ** Math.floor(Math.log10(rawStep));
    const step = [1, 2, 2.5, 5, 10].map((m) => m * mag).find((s) => s >= rawStep) || rawStep;
    const top = max > 0 ? Math.ceil(max / step) * step : 3 * step;
    const ticks = [];
    for (let v = 0; v <= top + 1e-9; v += step) ticks.push(v);

    const y = (v) => pad.top + plotH - (v / top) * plotH;
    const band = plotW / days.length;
    const barW = Math.max(2, Math.min(24, band - 2)); // <= 24px, 2px surface gap
    const labelEvery = Math.ceil(days.length / 8);

    const grid = ticks.map((t) => `
      <line x1="${pad.left}" x2="${W - pad.right}" y1="${y(t)}" y2="${y(t)}" stroke="#E6EBEF" stroke-width="1" />
      <text x="${pad.left - 8}" y="${y(t) + 4}" text-anchor="end" class="op-chart__tick">${esc(pesoShort(t))}</text>`).join('');

    const bars = days.map((d, i) => {
      const x = pad.left + i * band + (band - barW) / 2;
      const h = Math.max(0, y(0) - y(d.amount));
      const r = Math.min(4, barW / 2, h);
      // Rounded data-end (top), square at the baseline.
      const path = h > 0
        ? `M${x},${y(0)} V${y(0) - h + r} Q${x},${y(0) - h} ${x + r},${y(0) - h} H${x + barW - r} Q${x + barW},${y(0) - h} ${x + barW},${y(0) - h + r} V${y(0)} Z`
        : '';
      // Counted back from the last day, so it is always labelled and spacing stays even.
      const label = (days.length - 1 - i) % labelEvery === 0
        ? `<text x="${pad.left + i * band + band / 2}" y="${H - 8}" text-anchor="middle" class="op-chart__tick">${esc(dayLabel(d.date))}</text>`
        : '';
      // Hit target spans the full band and plot height.
      return `
        ${path ? `<path d="${path}" fill="${BAR_COLOR}" />` : ''}
        <rect class="op-chart__hit" x="${pad.left + i * band}" y="${pad.top}" width="${band}" height="${plotH}"
          fill="transparent" data-index="${i}" />
        ${label}`;
    }).join('');

    return `
      <svg viewBox="0 0 ${W} ${H}" class="op-chart__svg" role="img" aria-label="Daily revenue chart">
        ${grid}
        <line x1="${pad.left}" x2="${W - pad.right}" y1="${y(0)}" y2="${y(0)}" stroke="#C9D2D8" stroke-width="1" />
        ${bars}
      </svg>
      <div class="op-chart__tooltip" hidden></div>`;
  }

  function bindTooltip(chartEl, days) {
    const tip = chartEl.querySelector('.op-chart__tooltip');
    chartEl.querySelectorAll('.op-chart__hit').forEach((hit) => {
      hit.addEventListener('mouseenter', () => {
        const d = days[Number(hit.dataset.index)];
        tip.innerHTML = `
          <strong>${esc(dayLabel(d.date, { weekday: 'short', month: 'short', day: 'numeric' }))}</strong>
          <div>${esc(peso(d.amount))}</div>
          <div class="op-chart__tooltip-muted">${d.remittances} ${d.remittances === 1 ? 'remittance' : 'remittances'}</div>`;
        tip.hidden = false;
        hit.setAttribute('fill', 'rgba(31,127,181,0.08)');
      });
      hit.addEventListener('mousemove', (e) => {
        const box = chartEl.getBoundingClientRect();
        const x = e.clientX - box.left;
        tip.style.left = `${Math.min(x + 14, box.width - tip.offsetWidth - 4)}px`;
        tip.style.top = `${e.clientY - box.top - tip.offsetHeight - 10}px`;
      });
      hit.addEventListener('mouseleave', () => {
        tip.hidden = true;
        hit.setAttribute('fill', 'transparent');
      });
    });
  }

  // ---------- Breakdowns ----------

  function breakdown(title, groups) {
    const rows = groups.length
      ? groups.slice(0, 8).map((g) => `
          <div class="op-rank">
            <div class="op-rank__head">
              <span class="op-rank__label" title="${esc(g.label)}">${esc(g.label)}</span>
              <span class="op-rank__value">${esc(peso(g.amount))}</span>
            </div>
            <div class="op-rank__track"><div class="op-rank__bar" style="width:${Math.max(g.share_percent, 1)}%;background:${BAR_COLOR};"></div></div>
            <div class="op-rank__meta">${g.share_percent}% · ${g.remittances} ${g.remittances === 1 ? 'remittance' : 'remittances'}</div>
          </div>`).join('')
        + (groups.length > 8 ? `<p class="op-card__sub" style="margin:8px 0 0;">+ ${groups.length - 8} more</p>` : '')
      : AdminUi.stateMessage('No revenue in this period.');
    return `<section class="op-card"><h3>${esc(title)}</h3>${rows}</section>`;
  }

  // ---------- Mount ----------

  function mount(container) {
    let range = '30';
    const custom = { start: addDays(todayIso(), -29), end: todayIso() };
    let summary = null;
    let log = [];
    let fleet = [];
    let drivers = [];

    container.innerHTML = `
      <section class="op-revenue">
        <div class="op-page-head" style="align-items:center;">
          <div>
            <h2>Revenue Report</h2>
            <p>From the daily remittances you record for each vehicle.</p>
          </div>
          <button type="button" class="op-btn" id="rev-record">＋ Record Remittance</button>
        </div>
        <div class="op-breakdown" style="margin:0 0 var(--space-sm);align-items:center;">
          <div id="rev-ranges" style="display:flex;gap:8px;flex-wrap:wrap;"></div>
          <div id="rev-custom" style="display:none;gap:8px;align-items:center;">
            <input type="date" id="rev-start" class="op-date" aria-label="Start date" />
            <span style="color:var(--op-muted);">to</span>
            <input type="date" id="rev-end" class="op-date" aria-label="End date" />
          </div>
        </div>
        <div id="rev-kpis"></div>
        <section class="op-card" style="margin-bottom:var(--space-sm);">
          <h3>Daily Revenue</h3>
          <p class="op-card__sub" id="rev-chart-sub"></p>
          <div class="op-chart" id="rev-chart"></div>
        </section>
        <div class="op-grid" id="rev-breakdowns" style="margin-bottom:var(--space-sm);"></div>
        <section class="op-card op-card--flush" style="margin-bottom:var(--space-md);">
          <div class="op-card__head">
            <div class="op-page-head" style="margin:0;">
              <div>
                <h3>Remittance Log</h3>
                <p class="op-card__sub" style="margin:0;" id="rev-log-sub"></p>
              </div>
              <button type="button" class="btn-sm btn-sm--teal" id="rev-export" disabled>Export CSV</button>
            </div>
          </div>
          <div id="rev-log"></div>
        </section>
      </section>`;

    const $ = (sel) => container.querySelector(sel);
    const rangesEl = $('#rev-ranges');
    const customEl = $('#rev-custom');
    const startInput = $('#rev-start');
    const endInput = $('#rev-end');
    const kpisEl = $('#rev-kpis');
    const chartEl = $('#rev-chart');
    const chartSub = $('#rev-chart-sub');
    const breakdownsEl = $('#rev-breakdowns');
    const logEl = $('#rev-log');
    const logSub = $('#rev-log-sub');
    const exportBtn = $('#rev-export');

    startInput.value = custom.start;
    endInput.value = custom.end;
    startInput.max = endInput.max = todayIso();

    function renderRanges() {
      rangesEl.innerHTML = AdminUi.filterChips(RANGES, range, 'range');
      customEl.style.display = range === 'custom' ? 'flex' : 'none';
    }

    function renderKpis() {
      const s = summary;
      kpisEl.innerHTML = OperatorUi.stats([
        ['Today', s ? peso(s.today) : undefined],
        ['Last 7 Days', s ? peso(s.last_7_days) : undefined, 'blue'],
        ['This Month', s ? peso(s.this_month) : undefined, 'green'],
        ['Selected Period', s ? peso(s.total) : undefined],
      ]);
    }

    function renderSummary() {
      const s = summary;
      const { start, end } = s;
      chartSub.textContent = `${dayLabel(start, { month: 'short', day: 'numeric', year: 'numeric' })} – ${dayLabel(end, { month: 'short', day: 'numeric', year: 'numeric' })} · ${peso(s.total)} total · ${peso(s.average_per_day)} per day on average${s.remittances ? ` · ${peso(s.average_per_remittance)} per vehicle-day` : ''}`;
      if (!s.remittances) {
        chartEl.innerHTML = AdminUi.stateMessage('No remittances recorded in this period. Click Record Remittance to add one.');
      } else {
        chartEl.innerHTML = chartSvg(s.by_day);
        bindTooltip(chartEl, s.by_day);
      }
      breakdownsEl.innerHTML = [
        breakdown('By Route', s.by_route),
        breakdown('By Vehicle', s.by_vehicle),
        breakdown('By Driver', s.by_driver),
      ].join('');
    }

    function renderLog() {
      const total = log.reduce((n, r) => n + r.amount, 0);
      logSub.textContent = `${log.length} ${log.length === 1 ? 'remittance' : 'remittances'} · ${peso(total)}`;
      exportBtn.disabled = !log.length;
      const rows = log.length
        ? log.map((r) => `
            <tr>
              <td style="white-space:nowrap;">${esc(dayLabel(r.date, { month: 'short', day: 'numeric', year: 'numeric' }))}</td>
              <td class="data-table__name">${esc(r.plate_number)}</td>
              <td>${esc(r.route_code || '—')}</td>
              <td>${esc(r.driver_name || '—')}</td>
              <td>${r.trips ?? '—'}</td>
              <td>${r.passengers ?? '—'}</td>
              <td style="font-weight:600;white-space:nowrap;">${esc(peso(r.amount))}</td>
              <td style="max-width:220px;">${esc(r.notes || '')}</td>
              <td>
                <div class="data-table__actions">
                  <button type="button" class="btn-sm btn-sm--teal" data-action="edit" data-id="${r.id}">Edit</button>
                  <button type="button" class="btn-sm btn-sm--danger" data-action="delete" data-id="${r.id}">Delete</button>
                </div>
              </td>
            </tr>`).join('')
        : '<tr><td colspan="9" class="data-table__empty">No remittances in this period.</td></tr>';
      logEl.innerHTML = `
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Date</th><th>Vehicle</th><th>Route</th><th>Driver</th><th>Trips</th><th>Passengers</th><th>Amount</th><th>Notes</th><th>Actions</th></tr></thead>
            <tbody>${rows}</tbody>
          </table>
        </div>`;
    }

    async function load() {
      const current = rangeFor(range, custom);
      summary = null;
      renderKpis();
      chartEl.innerHTML = AdminUi.stateMessage('Loading…');
      breakdownsEl.innerHTML = '';
      await AdminUi.loadInto(logEl, async () => {
        const [s, l] = await Promise.all([OperatorApi.revenueSummary(current), OperatorApi.remittances(current)]);
        return { s, l };
      }, ({ s, l }) => {
        summary = s;
        log = l;
        renderKpis();
        renderSummary();
        renderLog();
      });
      if (!summary) {
        kpisEl.innerHTML = '';
        chartEl.innerHTML = '';
        chartSub.textContent = '';
      }
    }

    // Vehicles and drivers for the record/edit forms.
    Promise.all([OperatorApi.fleet().catch(() => []), OperatorApi.drivers().catch(() => [])])
      .then(([f, d]) => { fleet = f; drivers = d; });

    // ---------- Forms ----------

    const driverOptions = (selected) => `<option value="">No driver recorded</option>${drivers
      .map((d) => `<option value="${esc(d.id)}"${d.id === selected ? ' selected' : ''}>${esc(OperatorUi.driverName(d))} (${esc(d.driver_code)})</option>`).join('')}`;

    function numbersFields(r = {}) {
      return `
        <div class="form-field">
          <label for="rm-amount">Amount Remitted (₱)</label>
          <input id="rm-amount" type="number" min="0.01" step="0.01" value="${r.amount ?? ''}" placeholder="e.g. 1850" />
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
          <div class="form-field">
            <label for="rm-trips">Trips (optional)</label>
            <input id="rm-trips" type="number" min="0" step="1" value="${r.trips ?? ''}" />
          </div>
          <div class="form-field">
            <label for="rm-passengers">Passengers (optional)</label>
            <input id="rm-passengers" type="number" min="0" step="1" value="${r.passengers ?? ''}" />
          </div>
        </div>
        <div class="form-field">
          <label for="rm-notes">Notes (optional)</label>
          <input id="rm-notes" maxlength="300" value="${esc(r.notes || '')}" placeholder="e.g. Short trip — flat tire at 2 PM" />
        </div>`;
    }

    function readNumbers(m) {
      const amount = Number(m.querySelector('#rm-amount').value);
      if (!(amount > 0)) throw new Error('Enter the amount remitted.');
      const optionalInt = (id) => {
        const raw = m.querySelector(id).value.trim();
        if (!raw) return null;
        const n = Number(raw);
        if (!Number.isInteger(n) || n < 0) throw new Error('Trips and passengers must be whole numbers.');
        return n;
      };
      return {
        amount,
        trips: optionalInt('#rm-trips'),
        passengers: optionalInt('#rm-passengers'),
        notes: m.querySelector('#rm-notes').value.trim() || null,
      };
    }

    function openRecord() {
      if (!fleet.length) {
        AdminModal.open({
          title: 'Record Remittance',
          size: 'sm',
          body: '<p class="modal-text">Add a vehicle to your fleet first — each remittance belongs to one vehicle.</p>',
          actions: [{ label: 'Go to Vehicles', variant: 'primary', onClick: () => { AdminModal.close(); location.hash = '#/vehicles'; } }],
        });
        return;
      }
      const first = fleet[0];
      const modal = AdminModal.open({
        title: 'Record Remittance',
        size: 'sm',
        body: `
          <form novalidate>
            <div class="form-field">
              <label for="rm-date">Date</label>
              <input id="rm-date" type="date" value="${todayIso()}" max="${todayIso()}" />
            </div>
            <div class="form-field">
              <label for="rm-vehicle">Vehicle</label>
              <select id="rm-vehicle">${fleet.map((v) => `<option value="${esc(v.vehicle_id)}">${esc(v.plate_number)}</option>`).join('')}</select>
            </div>
            <div class="form-field">
              <label for="rm-driver">Driver</label>
              <select id="rm-driver">${driverOptions(first.driver_id)}</select>
            </div>
            ${numbersFields()}
          </form>`,
        actions: [
          { label: 'Cancel', variant: 'ghost', onClick: AdminModal.close },
          {
            label: 'Save',
            variant: 'primary',
            onClick: async (m) => {
              const day = m.querySelector('#rm-date').value;
              if (!day) throw new Error('Choose the date.');
              if (day > todayIso()) throw new Error('A remittance can\'t be recorded for a future date.');
              const body = {
                date: day,
                vehicle_id: m.querySelector('#rm-vehicle').value,
                driver_id: m.querySelector('#rm-driver').value || null,
                ...readNumbers(m),
              };
              const saved = await OperatorApi.recordRemittance(body);
              AdminModal.close();
              AdminUi.toast(`${peso(saved.amount)} recorded for ${saved.plate_number}.`);
              load();
            },
          },
        ],
      });
      // Default the driver to whoever is assigned to the chosen vehicle.
      modal.querySelector('#rm-vehicle').addEventListener('change', (e) => {
        const vehicle = fleet.find((v) => v.vehicle_id === e.target.value);
        modal.querySelector('#rm-driver').value = vehicle?.driver_id || '';
      });
      modal.querySelector('#rm-amount').focus();
    }

    function openEdit(r) {
      AdminModal.open({
        title: `Edit Remittance — ${r.plate_number}`,
        size: 'sm',
        body: `
          <form novalidate>
            <div class="form-field">
              <label for="rm-date">Date</label>
              <input id="rm-date" type="date" value="${esc(r.date)}" max="${todayIso()}" />
            </div>
            <div class="form-field">
              <label for="rm-driver">Driver</label>
              <select id="rm-driver">${driverOptions(r.driver_id)}</select>
            </div>
            ${numbersFields(r)}
          </form>`,
        actions: [
          { label: 'Cancel', variant: 'ghost', onClick: AdminModal.close },
          {
            label: 'Save Changes',
            variant: 'primary',
            onClick: async (m) => {
              const day = m.querySelector('#rm-date').value;
              if (!day) throw new Error('Choose the date.');
              const changes = { date: day, ...readNumbers(m) };
              const driverId = m.querySelector('#rm-driver').value || null;
              // Keep a removed driver's saved name unless a different one is picked.
              if (driverId !== r.driver_id && (driverId || drivers.some((d) => d.id === r.driver_id))) {
                changes.driver_id = driverId;
              }
              await OperatorApi.updateRemittance(r.id, changes);
              AdminModal.close();
              AdminUi.toast('Remittance updated.');
              load();
            },
          },
        ],
      });
    }

    function confirmDelete(r) {
      AdminModal.confirm({
        title: 'Delete remittance?',
        message: `${peso(r.amount)} for ${r.plate_number} on ${dayLabel(r.date, { month: 'short', day: 'numeric', year: 'numeric' })} will be removed from your revenue. This cannot be undone.`,
        confirmLabel: 'Delete',
        onConfirm: async () => {
          await OperatorApi.deleteRemittance(r.id);
          AdminUi.toast('Remittance deleted.');
          load();
        },
      });
    }

    function exportCsv() {
      const cell = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`;
      const lines = [
        ['Date', 'Vehicle', 'Route', 'Driver', 'Trips', 'Passengers', 'Amount (PHP)', 'Notes'].map(cell).join(','),
        ...log.map((r) => [r.date, r.plate_number, r.route_code, r.driver_name, r.trips, r.passengers, r.amount.toFixed(2), r.notes]
          .map(cell).join(',')),
      ];
      const { start, end } = rangeFor(range, custom);
      const url = URL.createObjectURL(new Blob([`﻿${lines.join('\r\n')}`], { type: 'text/csv;charset=utf-8' }));
      const link = Object.assign(document.createElement('a'), { href: url, download: `smartcommute-revenue-${start}-to-${end}.csv` });
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
    }

    // ---------- Events ----------

    rangesEl.addEventListener('click', (e) => {
      const chip = e.target.closest('[data-range]');
      if (!chip) return;
      range = chip.dataset.range;
      renderRanges();
      load();
    });

    customEl.addEventListener('change', () => {
      if (!startInput.value || !endInput.value) return;
      if (startInput.value > endInput.value) {
        AdminUi.toast('The start date must be on or before the end date.', { error: true });
        return;
      }
      custom.start = startInput.value;
      custom.end = endInput.value;
      load();
    });

    logEl.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-action]');
      if (!btn) return;
      const r = log.find((x) => x.id === btn.dataset.id);
      if (!r) return;
      if (btn.dataset.action === 'edit') openEdit(r);
      else confirmDelete(r);
    });

    $('#rev-record').addEventListener('click', openRecord);
    exportBtn.addEventListener('click', exportCsv);

    renderRanges();
    load();
  }

  return { mount };
})();
