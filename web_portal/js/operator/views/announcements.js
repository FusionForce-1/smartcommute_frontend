// js/operator/views/announcements.js
//
// Announcements: publish transit alerts to commuters and drivers, and
// resolve / reopen / delete the ones already published.

OperatorRouter.register('announcements', {
  title: 'Announcements',
  heading: 'Transit Alerts',

  mount(el) {
    const esc = AdminUi.escapeHtml;
    let alerts;          // undefined = loading
    let routes = [];
    let severity = 'info';
    const busy = new Set();

    el.innerHTML = `
      <div class="op-alerts-layout">
        <form class="op-card" id="alert-form" novalidate>
          <h3>Create Transit Alert</h3>
          <p class="op-card__sub">Notify commuters and drivers about service changes.</p>
          <div class="op-form__grid">
            <div class="op-field op-field--full">
              <label for="af-title">Alert Title</label>
              <input id="af-title" maxlength="100" placeholder="Short alert heading" />
            </div>
            <div class="op-field op-field--full">
              <label for="af-message">Message</label>
              <textarea id="af-message" maxlength="1000" placeholder="Describe the service update..."></textarea>
            </div>
            <div class="op-field op-field--full">
              <label>Severity</label>
              <div class="op-severity" id="af-severity">
                ${Object.entries(OperatorUi.SEVERITY).map(([value, s]) => `
                  <button type="button" data-severity="${value}">${s.button}</button>`).join('')}
              </div>
            </div>
            <div class="op-field op-field--full">
              <label for="af-route">Affected Route</label>
              <select id="af-route"><option value="">All routes</option></select>
            </div>
          </div>
          <div class="op-form__error" id="af-error" hidden></div>
          <button type="submit" class="op-btn" id="af-submit" style="width:100%;margin-top:16px;" disabled>Publish Alert</button>
        </form>

        <section>
          <div class="op-page-head">
            <div>
              <h2>Published Alerts</h2>
              <p id="alert-count">Loading alerts…</p>
            </div>
            <span class="op-chip op-chip--blue" title="New alerts are pushed live to connected commuters and drivers.">🔔 Live notifications</span>
          </div>
          <div id="alert-list"></div>
        </section>
      </div>`;

    const form = el.querySelector('#alert-form');
    const titleInput = form.querySelector('#af-title');
    const messageInput = form.querySelector('#af-message');
    const routeSelect = form.querySelector('#af-route');
    const severityEl = form.querySelector('#af-severity');
    const errorEl = form.querySelector('#af-error');
    const submitBtn = form.querySelector('#af-submit');
    const listEl = el.querySelector('#alert-list');
    const countEl = el.querySelector('#alert-count');

    // ---------- Form ----------

    function renderSeverity() {
      severityEl.querySelectorAll('[data-severity]').forEach((b) => {
        b.classList.toggle('is-active', b.dataset.severity === severity);
        b.setAttribute('aria-pressed', String(b.dataset.severity === severity));
      });
    }

    function renderRouteOptions() {
      const current = routeSelect.value;
      routeSelect.innerHTML = `<option value="">All routes</option>${routes
        .map((r) => `<option value="${esc(r.id)}">${esc(`${r.code} – ${r.name}`)}</option>`).join('')}`;
      if (routes.some((r) => r.id === current)) routeSelect.value = current;
    }

    const complete = () => titleInput.value.trim() && messageInput.value.trim();

    form.addEventListener('input', () => {
      errorEl.hidden = true;
      submitBtn.disabled = !complete();
    });

    severityEl.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-severity]');
      if (!btn) return;
      severity = btn.dataset.severity;
      renderSeverity();
    });

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      if (!complete()) return;
      submitBtn.disabled = true;
      submitBtn.textContent = 'Publishing…';
      try {
        const alert = await OperatorApi.publishAlert({
          title: titleInput.value.trim(),
          message: messageInput.value.trim(),
          severity,
          route_id: routeSelect.value,
        });
        form.reset();
        severity = 'info';
        renderSeverity();
        if (Array.isArray(alerts)) {
          alerts = [alert, ...alerts];
          renderList();
        }
        AdminUi.toast(`"${alert.title}" was published.`);
      } catch (err) {
        errorEl.textContent = err.message || 'Unable to publish alert.';
        errorEl.hidden = false;
      } finally {
        submitBtn.textContent = 'Publish Alert';
        submitBtn.disabled = !complete();
      }
    });

    // ---------- List ----------

    function sortAlerts() {
      const newest = (a, b) => (OperatorUi.parseDate(b.created_at) || 0) - (OperatorUi.parseDate(a.created_at) || 0);
      alerts.sort((a, b) => (a.is_resolved - b.is_resolved) || newest(a, b));
    }

    function alertCard(a) {
      const sev = OperatorUi.SEVERITY[a.severity] || OperatorUi.SEVERITY.info;
      const isBusy = busy.has(a.id);
      const variant = a.is_resolved ? 'op-alert--resolved' : a.severity === 'info' ? '' : `op-alert--${a.severity}`;
      return `
        <article class="op-alert ${variant}">
          <div class="op-alert__icon" style="background:var(--op-${sev.tone}-bg);color:var(--op-${sev.tone});">!</div>
          <div class="op-alert__main">
            <div class="op-alert__chips">
              ${OperatorUi.chip(sev.label, sev.tone)}
              ${OperatorUi.chip(a.route_code || 'All routes')}
              ${a.is_resolved ? '<span style="color:var(--op-green);font-size:0.75rem;font-weight:600;">Resolved</span>' : ''}
            </div>
            <h4 class="op-alert__title">${esc(a.title)}</h4>
            <p class="op-alert__message">${esc(a.message)}</p>
            <div class="op-alert__foot">
              <span>🕒 ${esc(OperatorUi.timeAgo(a.created_at))}</span>
              <button type="button" class="op-text-btn ${a.is_resolved ? 'op-text-btn--blue' : 'op-text-btn--green'}"
                data-action="resolve" data-id="${a.id}" ${isBusy ? 'disabled' : ''}>
                ${a.is_resolved ? 'Reopen alert' : 'Mark as resolved'}
              </button>
            </div>
          </div>
          <button type="button" class="op-icon-btn op-icon-btn--plain" data-action="delete" data-id="${a.id}"
            title="Delete alert" aria-label="Delete alert" ${isBusy ? 'disabled' : ''}>${OperatorUi.TRASH_ICON}</button>
        </article>`;
    }

    function renderList() {
      sortAlerts();
      const active = alerts.filter((a) => !a.is_resolved).length;
      countEl.textContent = `${active} active ${active === 1 ? 'alert' : 'alerts'}`;
      listEl.innerHTML = alerts.length
        ? alerts.map(alertCard).join('')
        : `<div class="op-card">${AdminUi.stateMessage('No alerts yet. Alerts you publish will appear here.')}</div>`;
    }

    function load() {
      alerts = undefined;
      AdminUi.loadInto(listEl, OperatorApi.myAlerts, (list) => {
        alerts = list;
        renderList();
      }).then(() => {
        if (!Array.isArray(alerts)) countEl.textContent = '';
      });
      OperatorApi.myRoutes().then((list) => {
        routes = list;
        renderRouteOptions();
      }).catch(() => {});
    }

    async function toggleResolved(alert) {
      const resolve = !alert.is_resolved;
      busy.add(alert.id);
      renderList();
      try {
        const updated = await OperatorApi.setAlertResolved(alert.id, resolve);
        alerts = alerts.map((a) => (a.id === alert.id ? updated : a));
        AdminUi.toast(resolve ? 'Alert marked as resolved.' : 'Alert reopened.');
      } catch (err) {
        AdminUi.toast(err.message || 'Unable to update alert.', { error: true });
      } finally {
        busy.delete(alert.id);
        renderList();
      }
    }

    function confirmDelete(alert) {
      AdminModal.confirm({
        title: 'Delete alert?',
        message: `"${alert.title}" will be removed for commuters and drivers. This cannot be undone.`,
        confirmLabel: 'Delete',
        onConfirm: async () => {
          await OperatorApi.deleteAlert(alert.id);
          alerts = alerts.filter((a) => a.id !== alert.id);
          renderList();
          AdminUi.toast('Alert deleted.');
        },
      });
    }

    listEl.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-action]');
      if (!btn || !Array.isArray(alerts)) return;
      const alert = alerts.find((a) => a.id === btn.dataset.id);
      if (!alert) return;
      if (btn.dataset.action === 'resolve') toggleResolved(alert);
      else confirmDelete(alert);
    });

    renderSeverity();
    load();
  },
});
