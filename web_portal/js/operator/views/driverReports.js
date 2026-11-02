// js/operator/views/driverReports.js
//
// Driver Reports: what this operator's drivers sent from the app (an
// emergency, a breakdown, a delay, ...), newest first, with the shift's
// plate, route and location the backend attached. The operator marks them
// read here; drivers never see that, and can't be replied to this way.
// New reports also toast on every page (js/operator/driverReportAlerts.js).

OperatorRouter.register('driver-reports', {
  title: 'Driver Reports',
  heading: 'Driver Reports',

  mount(el) {
    const PAGE = 50;
    const esc = AdminUi.escapeHtml;
    const SHOW = [{ value: 'all', label: 'All' }, { value: 'unread', label: 'Unread' }];

    let reports;         // undefined = loading
    let show = 'all';
    let category = '';
    let hasMore = false;
    const busy = new Set();

    el.innerHTML = `
      <div class="op-page-head">
        <div>
          <h2>From your drivers</h2>
          <p id="dr-count">Loading reports…</p>
        </div>
        <button type="button" class="op-btn op-btn--outline" id="dr-read-all" style="width:auto;" hidden>Mark all as read</button>
      </div>
      <div class="op-dr-filters">
        <div id="dr-show" style="display:flex;gap:8px;flex-wrap:wrap;"></div>
        <div class="op-field">
          <select id="dr-category" aria-label="Report type">
            <option value="">All types</option>
            ${Object.entries(OperatorUi.REPORT_CATEGORY)
              .map(([value, c]) => `<option value="${value}">${esc(c.label)}</option>`).join('')}
          </select>
        </div>
      </div>
      <div id="dr-list"></div>
      <button type="button" class="op-btn op-btn--outline" id="dr-more" hidden>Load more</button>`;

    const showEl = el.querySelector('#dr-show');
    const categorySelect = el.querySelector('#dr-category');
    const listEl = el.querySelector('#dr-list');
    const countEl = el.querySelector('#dr-count');
    const readAllBtn = el.querySelector('#dr-read-all');
    const moreBtn = el.querySelector('#dr-more');

    const query = (skip = 0) => ({ unreadOnly: show === 'unread', category, skip, limit: PAGE });
    const syncBadge = () => DriverReportAlerts.refresh().catch(() => {});

    function renderShow() {
      showEl.innerHTML = AdminUi.filterChips(SHOW, show, 'show');
    }

    function contextLine(c) {
      if (!c) return OperatorUi.chip('Off shift');
      const parts = [OperatorUi.chip(c.plate_number)];
      if (c.route_code) parts.push(OperatorUi.chip(c.route_code));
      if (typeof c.lat === 'number' && typeof c.lng === 'number') {
        const href = `https://www.openstreetmap.org/?mlat=${c.lat}&mlon=${c.lng}#map=17/${c.lat}/${c.lng}`;
        parts.push(`<a class="op-link" style="margin:0;" href="${href}" target="_blank" rel="noopener">📍 Where it was sent</a>`);
      }
      return parts.join(' ');
    }

    function reportCard(r) {
      const cat = OperatorUi.REPORT_CATEGORY[r.category] || OperatorUi.REPORT_CATEGORY.other;
      const tone = cat.tone || 'blue';
      const variant = r.is_read ? 'op-alert--resolved' : r.category === 'emergency' ? 'op-alert--critical' : 'op-alert--warning';
      const who = r.driver_code ? `${r.driver_name} · ${r.driver_code}` : r.driver_name;
      return `
        <article class="op-alert ${variant}">
          <div class="op-alert__icon" style="background:var(--op-${tone}-bg);color:var(--op-${tone});">!</div>
          <div class="op-alert__main">
            <div class="op-alert__chips">
              ${OperatorUi.chip(cat.label, cat.tone)}
              ${r.is_read ? '' : OperatorUi.chip('New', 'blue')}
              ${contextLine(r.context)}
            </div>
            <h4 class="op-alert__title">${esc(who)}</h4>
            ${r.note ? `<p class="op-alert__message">${esc(r.note)}</p>` : ''}
            <div class="op-alert__foot">
              <span title="${esc(AdminUi.formatDateTime(r.created_at))}">🕒 ${esc(OperatorUi.timeAgo(r.created_at))}</span>
              ${r.is_read
                ? `<span>Read ${esc(OperatorUi.timeAgo(r.read_at))}</span>`
                : `<button type="button" class="op-text-btn op-text-btn--green" data-action="read" data-id="${r.id}"
                    ${busy.has(r.id) ? 'disabled' : ''}>Mark as read</button>`}
            </div>
          </div>
        </article>`;
    }

    function renderList() {
      const unread = reports.filter((r) => !r.is_read).length;
      countEl.textContent = show === 'unread'
        ? `${reports.length}${hasMore ? '+' : ''} unread`
        : `${reports.length}${hasMore ? '+' : ''} ${reports.length === 1 ? 'report' : 'reports'}, ${unread} unread`;
      readAllBtn.hidden = !unread;
      moreBtn.hidden = !hasMore;
      listEl.innerHTML = reports.length
        ? reports.map(reportCard).join('')
        : `<div class="op-card">${AdminUi.stateMessage(show === 'unread' || category
          ? 'No reports match this filter.'
          : 'No reports yet. When a driver sends one from the app, it shows up here.')}</div>`;
    }

    function load() {
      reports = undefined;
      readAllBtn.hidden = true;
      moreBtn.hidden = true;
      countEl.textContent = 'Loading reports…';
      AdminUi.loadInto(listEl, () => OperatorApi.driverReports(query()), (list) => {
        reports = list;
        hasMore = list.length === PAGE;
        renderList();
      }).then(() => {
        if (!Array.isArray(reports)) countEl.textContent = '';
      });
    }

    async function loadMore() {
      moreBtn.disabled = true;
      try {
        const next = await OperatorApi.driverReports(query(reports.length));
        const known = new Set(reports.map((r) => r.id));
        reports = [...reports, ...next.filter((r) => !known.has(r.id))];
        hasMore = next.length === PAGE;
        renderList();
      } catch (err) {
        AdminUi.toast(err.message || 'Unable to load more reports.', { error: true });
      } finally {
        moreBtn.disabled = false;
      }
    }

    async function markRead(report) {
      busy.add(report.id);
      renderList();
      try {
        const updated = await OperatorApi.markDriverReportRead(report.id);
        reports = show === 'unread'
          ? reports.filter((r) => r.id !== report.id)
          : reports.map((r) => (r.id === report.id ? updated : r));
        syncBadge();
      } catch (err) {
        AdminUi.toast(err.message || 'Unable to mark the report as read.', { error: true });
      } finally {
        busy.delete(report.id);
        renderList();
      }
    }

    async function markAllRead() {
      readAllBtn.disabled = true;
      try {
        const { updated } = await OperatorApi.markAllDriverReportsRead();
        AdminUi.toast(`${updated} ${updated === 1 ? 'report' : 'reports'} marked as read.`);
        syncBadge();
        load();
      } catch (err) {
        AdminUi.toast(err.message || 'Unable to mark reports as read.', { error: true });
      } finally {
        readAllBtn.disabled = false;
      }
    }

    showEl.addEventListener('click', (e) => {
      const chip = e.target.closest('[data-show]');
      if (!chip || chip.dataset.show === show) return;
      show = chip.dataset.show;
      renderShow();
      load();
    });

    categorySelect.addEventListener('change', () => {
      category = categorySelect.value;
      load();
    });

    listEl.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-action="read"]');
      if (!btn || !Array.isArray(reports)) return;
      const report = reports.find((r) => r.id === btn.dataset.id);
      if (report) markRead(report);
    });

    readAllBtn.addEventListener('click', markAllRead);
    moreBtn.addEventListener('click', loadMore);

    // The poller found new reports while this page is open.
    const onNew = () => { if (Array.isArray(reports)) load(); };
    window.addEventListener('driver-reports:changed', onNew);

    renderShow();
    load();
    return () => window.removeEventListener('driver-reports:changed', onNew);
  },
});
