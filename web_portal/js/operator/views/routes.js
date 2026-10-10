// js/operator/views/routes.js
//
// Routes & Stops: the operator's routes with stop / fare / vehicle counts,
// a "Create New Route" card, and Pause / Activate / Delete per route.

OperatorRouter.register('routes', {
  title: 'Routes & Stops',
  heading: 'Route Management',

  mount(el) {
    const esc = AdminUi.escapeHtml;
    let routes;          // undefined = loading
    let showForm = false;
    const busy = new Set();

    el.innerHTML = `
      <div class="op-page-head">
        <div>
          <h2>Transit Routes</h2>
          <p>Manage service paths, fares, assigned vehicles, and availability.</p>
        </div>
        <button type="button" class="op-btn" id="route-toggle-form">＋ Add Route</button>
      </div>
      <div id="route-stats"></div>
      <div id="route-form-slot"></div>
      <div id="route-list"></div>`;

    const statsEl = el.querySelector('#route-stats');
    const formSlot = el.querySelector('#route-form-slot');
    const listEl = el.querySelector('#route-list');
    const toggleBtn = el.querySelector('#route-toggle-form');

    // ---------- Stats ----------

    function renderStats() {
      const loaded = Array.isArray(routes);
      const value = (fn) => (loaded ? fn() : undefined);
      statsEl.innerHTML = OperatorUi.stats([
        ['Total Routes', value(() => routes.length)],
        ['Active Routes', value(() => routes.filter((r) => r.is_active).length), 'green'],
        ['Assigned Vehicles', value(() => routes.reduce((n, r) => n + r.vehicle_count, 0)), 'blue'],
      ]);
    }

    // ---------- Create form ----------

    function renderForm() {
      toggleBtn.textContent = showForm ? '✕ Cancel' : '＋ Add Route';
      if (!showForm) {
        formSlot.innerHTML = '';
        return;
      }
      formSlot.innerHTML = `
        <form class="op-card op-form" id="route-form" novalidate style="margin-bottom:var(--space-sm);">
          <h3>Create New Route</h3>
          <p class="op-card__sub">New routes start inactive until you are ready to begin service.</p>
          <div class="op-form__grid">
            <div class="op-field">
              <label for="rf-code">Route Code</label>
              <input id="rf-code" maxlength="10" placeholder="e.g. J05" autocomplete="off" />
            </div>
            <div class="op-field">
              <label for="rf-name">Route Name</label>
              <input id="rf-name" maxlength="80" placeholder="e.g. Talamban – Pier 1" />
            </div>
            <div class="op-field">
              <label for="rf-origin">Origin</label>
              <input id="rf-origin" maxlength="80" placeholder="Starting terminal" />
            </div>
            <div class="op-field">
              <label for="rf-destination">Destination</label>
              <input id="rf-destination" maxlength="80" placeholder="End terminal" />
            </div>
            <div class="op-field">
              <label for="rf-fare">Base Fare (₱)</label>
              <input id="rf-fare" type="number" min="0.01" max="9999" step="0.01" placeholder="13" />
            </div>
          </div>
          <div class="op-form__error" id="rf-error" hidden></div>
          <div class="op-form__actions">
            <button type="submit" class="op-btn" id="rf-submit" disabled>Create Route</button>
          </div>
        </form>`;

      const form = formSlot.querySelector('#route-form');
      const field = (id) => form.querySelector(`#${id}`);
      const errorEl = field('rf-error');
      const submit = field('rf-submit');

      const values = () => ({
        code: field('rf-code').value.trim().toUpperCase(),
        name: field('rf-name').value.trim(),
        origin: field('rf-origin').value.trim(),
        destination: field('rf-destination').value.trim(),
        baseFare: Number(field('rf-fare').value),
      });
      const complete = (v) => v.code && v.name && v.origin && v.destination && v.baseFare > 0;

      form.addEventListener('input', (e) => {
        if (e.target.id === 'rf-code') {
          e.target.value = e.target.value.toUpperCase().replace(/[^A-Z0-9-]/g, '');
        }
        errorEl.hidden = true;
        submit.disabled = !complete(values());
      });

      form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const v = values();
        if (!complete(v)) return;
        submit.disabled = true;
        submit.textContent = 'Creating…';
        try {
          await OperatorApi.createRoute(v);
          showForm = false;
          renderForm();
          AdminUi.toast(`${v.code} – ${v.name} was created.`);
          load();
        } catch (err) {
          errorEl.textContent = err.message || 'Unable to create route.';
          errorEl.hidden = false;
          submit.disabled = false;
          submit.textContent = 'Create Route';
        }
      });

      field('rf-code').focus();
    }

    // ---------- Route cards ----------

    function routeCard(r) {
      const isBusy = busy.has(r.id);
      const action = !r.owned
        ? '<div class="op-muted-note">Managed by the operator who created this route</div>'
        : `<button type="button" class="op-btn ${r.is_active ? 'op-btn--outline-red' : 'op-btn--outline-green'}"
             data-action="toggle" data-id="${r.id}" ${isBusy ? 'disabled' : ''}>
             ${isBusy ? 'Saving…' : r.is_active ? 'Pause Route' : 'Activate Route'}
           </button>`;

      return `
        <article class="op-card op-route-card">
          <header class="op-route-card__head">
            <span class="op-code${r.is_active ? '' : ' op-code--inactive'}">${esc(r.code)}</span>
            <div class="op-route-card__title">
              <strong title="${esc(r.name)}">${esc(r.name)}</strong>
              ${r.is_active ? OperatorUi.chip('Active', 'green') : OperatorUi.chip('Inactive')}
              ${r.owned ? '' : OperatorUi.chip('Shared', 'blue')}
            </div>
            ${r.owned ? `
              <button type="button" class="op-icon-btn" data-action="delete" data-id="${r.id}"
                title="Delete route" aria-label="Delete ${esc(r.code)}" ${isBusy ? 'disabled' : ''}>${OperatorUi.TRASH_ICON}</button>` : ''}
          </header>
          <div class="op-route-card__body">
            <div class="op-terminals">
              <div class="op-terminals__row"><span class="op-terminals__from"></span>${esc(r.terminal_a || '—')}</div>
              <div class="op-terminals__line"></div>
              <div class="op-terminals__row"><span class="op-terminals__to"></span>${esc(r.terminal_b || '—')}</div>
            </div>
            <div class="op-route-stats">
              <div><span>Stops</span><strong>${r.stop_count}</strong></div>
              <div><span>Fare</span><strong>${OperatorUi.fare(r.base_fare)}</strong></div>
              <div><span>Vehicles</span><strong>${r.vehicle_count}</strong></div>
            </div>
            ${action}
          </div>
        </article>`;
    }

    function renderList() {
      listEl.innerHTML = routes.length
        ? `<div class="op-grid op-grid--2">${routes.map(routeCard).join('')}</div>`
        : `<div class="op-card">${AdminUi.stateMessage('No routes yet. Click Add Route to create your first route.')}</div>`;
    }

    function load() {
      routes = undefined;
      renderStats();
      AdminUi.loadInto(listEl, OperatorApi.myRoutes, (list) => {
        routes = list;
        renderStats();
        renderList();
      }).then(() => {
        if (!Array.isArray(routes)) statsEl.innerHTML = '';
      });
    }

    // ---------- Actions ----------

    async function setActive(route, active) {
      busy.add(route.id);
      renderList();
      try {
        await OperatorApi.setRouteActive(route.id, active);
        route.is_active = active;
        AdminUi.toast(`${route.code} is now ${active ? 'active' : 'paused'}.`);
      } catch (err) {
        AdminUi.toast(err.message || 'Unable to update route.', { error: true });
      } finally {
        busy.delete(route.id);
        renderStats();
        renderList();
      }
    }

    function toggle(route) {
      const activate = !route.is_active;
      if (activate || route.vehicle_count === 0) {
        setActive(route, activate);
        return;
      }
      AdminModal.confirm({
        title: 'Pause route?',
        message: `${route.code} – ${route.name} has ${route.vehicle_count} ${route.vehicle_count === 1 ? 'vehicle' : 'vehicles'} assigned. Commuters will no longer see this route until you activate it again.`,
        confirmLabel: 'Pause Route',
        onConfirm: () => setActive(route, false),
      });
    }

    function remove(route) {
      AdminModal.confirm({
        title: 'Delete route?',
        message: `${route.code} – ${route.name} will be removed permanently. This cannot be undone.`,
        confirmLabel: 'Delete',
        onConfirm: async () => {
          await OperatorApi.deleteRoute(route.id); // errors show inside the modal
          routes = routes.filter((r) => r.id !== route.id);
          AdminUi.toast(`${route.code} – ${route.name} was deleted.`);
          renderStats();
          renderList();
        },
      });
    }

    listEl.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-action]');
      if (!btn || !Array.isArray(routes)) return;
      const route = routes.find((r) => r.id === btn.dataset.id);
      if (!route) return;
      if (btn.dataset.action === 'toggle') toggle(route);
      else if (btn.dataset.action === 'delete') remove(route);
    });

    toggleBtn.addEventListener('click', () => {
      showForm = !showForm;
      renderForm();
    });

    renderForm();
    load();
  },
});
