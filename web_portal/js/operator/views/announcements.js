// js/operator/views/announcements.js
//
// Announcements: send notices (service alerts, schedule changes,
// promotions) to the commuters on this operator's routes, and withdraw the
// ones already sent. The backend picks the recipients; the operator only
// learns how many it reached. Drivers don't get these — they send reports
// the other way (Driver Reports).

OperatorRouter.register('announcements', {
  title: 'Announcements',
  heading: 'Announcements',

  mount(el) {
    const esc = AdminUi.escapeHtml;
    const ROUTE_CODES_SHOWN = 3;
    let notices;         // undefined = loading
    let targets = [];
    let severity = 'info';
    let requestId = null; // kept across retries of one send, so it can't go out twice
    const busy = new Set();

    el.innerHTML = `
      <div class="op-alerts-layout">
        <form class="op-card" id="notice-form" novalidate>
          <h3>New Announcement</h3>
          <p class="op-card__sub">Notify the commuters on your routes about service changes.</p>
          <div class="op-form__grid">
            <div class="op-field op-field--full">
              <label for="af-category">Type</label>
              <select id="af-category">
                ${Object.entries(OperatorUi.NOTICE_CATEGORY)
                  .map(([value, label]) => `<option value="${value}">${esc(label)}</option>`).join('')}
              </select>
            </div>
            <div class="op-field op-field--full">
              <label for="af-title">Title</label>
              <input id="af-title" maxlength="100" placeholder="Short heading" />
            </div>
            <div class="op-field op-field--full">
              <label for="af-message">Message</label>
              <textarea id="af-message" maxlength="1000" placeholder="Describe the service update..."></textarea>
            </div>
            <div class="op-field op-field--full" id="af-severity-field">
              <label>Severity</label>
              <div class="op-severity" id="af-severity">
                ${Object.entries(OperatorUi.SEVERITY).map(([value, s]) => `
                  <button type="button" data-severity="${value}">${s.button}</button>`).join('')}
              </div>
            </div>
            <div class="op-field op-field--full">
              <label for="af-route">Route</label>
              <select id="af-route"><option value="">All your routes</option></select>
            </div>
          </div>
          <div class="op-form__error" id="af-error" hidden></div>
          <button type="submit" class="op-btn" id="af-submit" style="width:100%;margin-top:16px;" disabled>Send Announcement</button>
        </form>

        <section>
          <div class="op-page-head">
            <div>
              <h2>Sent Announcements</h2>
              <p id="notice-count">Loading announcements…</p>
            </div>
          </div>
          <div id="notice-list"></div>
        </section>
      </div>`;

    const form = el.querySelector('#notice-form');
    const categorySelect = form.querySelector('#af-category');
    const titleInput = form.querySelector('#af-title');
    const messageInput = form.querySelector('#af-message');
    const routeSelect = form.querySelector('#af-route');
    const severityField = form.querySelector('#af-severity-field');
    const severityEl = form.querySelector('#af-severity');
    const errorEl = form.querySelector('#af-error');
    const submitBtn = form.querySelector('#af-submit');
    const listEl = el.querySelector('#notice-list');
    const countEl = el.querySelector('#notice-count');

    // ---------- Form ----------

    function renderSeverity() {
      severityField.hidden = categorySelect.value !== 'service_alert';
      severityEl.querySelectorAll('[data-severity]').forEach((b) => {
        b.classList.toggle('is-active', b.dataset.severity === severity);
        b.setAttribute('aria-pressed', String(b.dataset.severity === severity));
      });
    }

    function renderRouteOptions() {
      const current = routeSelect.value;
      routeSelect.innerHTML = `<option value="">All your routes</option>${targets
        .map((t) => `<option value="${esc(t.route_id)}">${esc([t.route_code, t.route_name].filter(Boolean).join(' – '))}</option>`)
        .join('')}`;
      if (targets.some((t) => t.route_id === current)) routeSelect.value = current;
    }

    const complete = () => titleInput.value.trim() && messageInput.value.trim();

    form.addEventListener('input', () => {
      errorEl.hidden = true;
      requestId = null;   // a changed announcement is a new one
      submitBtn.disabled = !complete();
      renderSeverity();
    });

    severityEl.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-severity]');
      if (!btn) return;
      severity = btn.dataset.severity;
      requestId = null;
      renderSeverity();
    });

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      if (!complete()) return;
      requestId ??= OperatorUi.requestId();
      submitBtn.disabled = true;
      submitBtn.textContent = 'Sending…';
      try {
        const notice = await OperatorApi.sendNotice({
          category: categorySelect.value,
          severity,
          title: titleInput.value.trim(),
          message: messageInput.value.trim(),
          route_id: routeSelect.value,
          client_request_id: requestId,
        });
        requestId = null;
        form.reset();
        severity = 'info';
        renderSeverity();
        if (Array.isArray(notices)) {
          notices = [notice, ...notices.filter((n) => n.id !== notice.id)];
          renderList();
        }
        const n = notice.recipient_count;
        AdminUi.toast(`"${notice.title}" was sent to ${n} ${n === 1 ? 'commuter' : 'commuters'}.`);
      } catch (err) {
        errorEl.textContent = err.message || 'Unable to send the announcement.';
        errorEl.hidden = false;
      } finally {
        submitBtn.textContent = 'Send Announcement';
        submitBtn.disabled = !complete();
      }
    });

    // ---------- List ----------

    function routesChip(codes) {
      if (!codes.length) return OperatorUi.chip('Your routes');
      const shown = codes.slice(0, ROUTE_CODES_SHOWN).join(', ');
      const more = codes.length - ROUTE_CODES_SHOWN;
      return OperatorUi.chip(more > 0 ? `${shown} +${more} more` : shown);
    }

    function noticeCard(n) {
      const isAlert = n.category === 'service_alert';
      const sev = OperatorUi.SEVERITY[n.severity] || OperatorUi.SEVERITY.info;
      const tone = isAlert ? sev.tone : n.category === 'promotion' ? 'green' : 'blue';
      const withdrawn = Boolean(n.withdrawn_at);
      const isBusy = busy.has(n.id);
      const variant = withdrawn ? 'op-alert--resolved' : isAlert && n.severity !== 'info' ? `op-alert--${n.severity}` : '';
      const reached = `${n.recipient_count} ${n.recipient_count === 1 ? 'commuter' : 'commuters'}`;
      return `
        <article class="op-alert ${variant}">
          <div class="op-alert__icon" style="background:var(--op-${tone}-bg);color:var(--op-${tone});">!</div>
          <div class="op-alert__main">
            <div class="op-alert__chips">
              ${OperatorUi.chip(OperatorUi.NOTICE_CATEGORY[n.category] || n.category, isAlert ? '' : tone)}
              ${isAlert ? OperatorUi.chip(sev.label, sev.tone) : ''}
              ${routesChip(n.route_codes || [])}
              ${withdrawn ? '<span style="color:var(--op-muted);font-size:0.75rem;font-weight:600;">Withdrawn</span>' : ''}
            </div>
            <h4 class="op-alert__title">${esc(n.title)}</h4>
            <p class="op-alert__message">${esc(n.message)}</p>
            <div class="op-alert__foot">
              <span>🕒 ${esc(OperatorUi.timeAgo(n.created_at))} · Reached ${reached}</span>
              ${withdrawn ? `<span>Withdrawn ${esc(OperatorUi.timeAgo(n.withdrawn_at))}</span>` : ''}
            </div>
          </div>
          ${withdrawn ? '' : `
            <button type="button" class="op-icon-btn op-icon-btn--plain" data-action="withdraw" data-id="${n.id}"
              title="Withdraw announcement" aria-label="Withdraw announcement" ${isBusy ? 'disabled' : ''}>${OperatorUi.TRASH_ICON}</button>`}
        </article>`;
    }

    function renderList() {
      // Newest first, withdrawn ones after the rest.
      const ordered = [...notices.filter((n) => !n.withdrawn_at), ...notices.filter((n) => n.withdrawn_at)];
      const active = notices.length - notices.filter((n) => n.withdrawn_at).length;
      countEl.textContent = `${active} active ${active === 1 ? 'announcement' : 'announcements'}`;
      listEl.innerHTML = ordered.length
        ? ordered.map(noticeCard).join('')
        : `<div class="op-card">${AdminUi.stateMessage('Nothing sent yet. Announcements you send will appear here.')}</div>`;
    }

    function load() {
      notices = undefined;
      AdminUi.loadInto(listEl, () => OperatorApi.sentNotices(), (list) => {
        notices = list;
        renderList();
      }).then(() => {
        if (!Array.isArray(notices)) countEl.textContent = '';
      });
      OperatorApi.noticeTargets().then((list) => {
        targets = list;
        renderRouteOptions();
      }).catch(() => {});
    }

    function confirmWithdraw(notice) {
      AdminModal.confirm({
        title: 'Withdraw announcement?',
        message: `"${notice.title}" will be removed from every commuter's inbox. This cannot be undone.`,
        confirmLabel: 'Withdraw',
        onConfirm: async () => {
          busy.add(notice.id);
          try {
            const updated = await OperatorApi.withdrawNotice(notice.id);
            notices = notices.map((n) => (n.id === notice.id ? updated : n));
            AdminUi.toast('Announcement withdrawn.');
          } finally {
            busy.delete(notice.id);
            renderList();
          }
        },
      });
    }

    listEl.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-action="withdraw"]');
      if (!btn || !Array.isArray(notices)) return;
      const notice = notices.find((n) => n.id === btn.dataset.id);
      if (notice) confirmWithdraw(notice);
    });

    renderSeverity();
    load();
  },
});
