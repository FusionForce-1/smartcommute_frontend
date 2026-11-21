// Operator routes view
OperatorRouter.register('routes', {
  title: 'Routes & Stops',
  heading: 'Route Management',

  // Mount the view
  mount(el) {
    const esc = AdminUi.escapeHtml;
    let routes;
    let statuses = {};
    let showForm = false;
    const busy = new Set();
    const STATUS_LABELS = { active: 'Normal', congested: 'Congested', suspended: 'Suspended' };

    // Fare rule text
    const fareRuleText = (r) => `₱${r.base} for the first ${r.base_km} km, then ₱${Number(r.per_km).toFixed(2)} per km. `
      + `Students, seniors and PWD get ${r.discount_pct}% off. Fares are fixed for every route.`;

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


    // Render stats
    function renderStats() {
      const loaded = Array.isArray(routes);
      // Routes value
      const value = (fn) => (loaded ? fn() : undefined);
      statsEl.innerHTML = OperatorUi.stats([
        ['Total Routes', value(() => routes.length)],
        ['Active Routes', value(() => routes.filter((r) => r.is_active).length), 'green'],
        ['Assigned Vehicles', value(() => routes.reduce((n, r) => n + r.vehicle_count, 0)), 'blue'],
      ]);
    }


    let formPicker = null;

    // Render form
    function renderForm() {
      toggleBtn.textContent = showForm ? '✕ Cancel' : '＋ Add Route';
      formPicker?.destroy();
      formPicker = null;
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
              <label>Fare</label>
              <p class="op-muted-note" id="rf-fare-rule">${esc(fareRuleText({ base: 17, base_km: 4, per_km: 2.4, discount_pct: 20 }))}</p>
            </div>
            <div class="op-field op-field--full">
              <label>Origin &amp; Destination</label>
              <div id="rf-picker"></div>
            </div>
          </div>
          <div class="op-form__error" id="rf-error" hidden></div>
          <div class="op-form__actions">
            <button type="submit" class="op-btn" id="rf-submit" disabled>Create Route</button>
          </div>
        </form>`;

      const form = formSlot.querySelector('#route-form');
      // Routes field
      const field = (id) => form.querySelector(`#${id}`);
      const errorEl = field('rf-error');
      const submit = field('rf-submit');

      let nameIsAuto = true;
      // Routes short
      const short = (place) => String(place || '').split(',')[0].trim();

      // Routes values
      const values = () => {
        const where = picker.value();
        return {
          code: field('rf-code').value.trim().toUpperCase(),
          name: field('rf-name').value.trim(),
          origin: where.origin?.name?.trim() || '',
          destination: where.destination?.name?.trim() || '',
          originAt: where.origin?.lng != null ? [where.origin.lng, where.origin.lat] : null,
          destinationAt: where.destination?.lng != null ? [where.destination.lng, where.destination.lat] : null,
          path: where.path,
        };
      };
      // Routes complete
      const complete = (v) => v.code && v.name && v.origin && v.destination;
      // Refresh routes
      const refresh = () => {
        errorEl.hidden = true;
        submit.disabled = !complete(values());
      };

      const picker = RoutePicker.mount(field('rf-picker'), {
        onChange: () => {
          const v = values();
          if (nameIsAuto && v.origin && v.destination) {
            field('rf-name').value = `${short(v.origin)} – ${short(v.destination)}`.slice(0, 80);
          }
          refresh();
        },
      });
      formPicker = picker;

      form.addEventListener('input', (e) => {
        if (e.target.id === 'rf-code') {
          e.target.value = e.target.value.toUpperCase().replace(/[^A-Z0-9-]/g, '');
        }
        if (e.target.id === 'rf-name') nameIsAuto = !e.target.value.trim();
        refresh();
      });

      form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const v = values();
        if (!complete(v)) return;
        submit.disabled = true;
        submit.textContent = 'Creating…';
        try {
          const created = await OperatorApi.createRoute(v);
          showForm = false;
          renderForm();
          const n = created?.stops_added || 0;
          AdminUi.toast(n
            ? `${v.code} – ${v.name} was created with ${n} usual stops along its path. Use "Edit stops" to add or remove any.`
            : `${v.code} – ${v.name} was created.`);
          load();
        } catch (err) {
          errorEl.textContent = err.message || 'Unable to create route.';
          errorEl.hidden = false;
          submit.disabled = false;
          submit.textContent = 'Create Route';
        }
      });

      OperatorApi.fareRule().then((rule) => {
        const line = form.querySelector('#rf-fare-rule');
        if (line && rule) line.textContent = fareRuleText(rule);
      }).catch(() => {});
      field('rf-code').focus();
    }


    // Route card
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
              <div><span>Stops</span><strong>${r.stop_count}</strong>
                ${r.owned ? `<button type="button" class="op-link" data-action="stops" data-id="${r.id}"
                  style="display:block;margin:4px auto 0;background:none;border:0;cursor:pointer;">${r.stop_count ? 'Edit stops' : 'Add stops'}</button>` : ''}</div>
              <div><span>Fare</span><strong>${OperatorUi.fare(r.base_fare)}</strong></div>
              <div><span>Vehicles</span><strong>${r.vehicle_count}</strong></div>
            </div>
            ${r.owned ? statusControl(r) : ''}
            ${r.owned && !r.has_return_line ? `<div class="op-muted-note" data-hint="no-return-line">Return trip uses the outbound line reversed; draw a return line if the jeep takes other streets.</div>` : ''}
            ${action}
          </div>
        </article>`;
    }

    // Route status control
    function statusControl(r) {
      const current = statuses[r.id] || 'active';
      return `
        <label class="op-field" style="margin:var(--space-xs) 0;">
          <span>Route status</span>
          <select data-action="status" data-id="${r.id}" ${busy.has(r.id) ? 'disabled' : ''}>
            ${Object.entries(STATUS_LABELS).map(([value, label]) =>
              `<option value="${value}" ${value === current ? 'selected' : ''}>${label}</option>`).join('')}
          </select>
        </label>`;
    }

    // Change route status
    async function changeStatus(route, status) {
      busy.add(route.id);
      try {
        await OperatorApi.setRouteStatus(route.id, status);
        statuses[route.id] = status;
        AdminUi.toast(status === 'congested'
          ? `${route.code} marked congested. It returns to normal by itself after an hour.`
          : `${route.code} is now ${STATUS_LABELS[status].toLowerCase()}.`);
      } catch (err) {
        AdminUi.toast(err.message || 'Unable to update route status.', { error: true });
      } finally {
        busy.delete(route.id);
        renderList();
      }
    }

    // Render list
    function renderList() {
      listEl.innerHTML = routes.length
        ? `<div class="op-grid op-grid--2">${routes.map(routeCard).join('')}</div>`
        : `<div class="op-card">${AdminUi.stateMessage('No routes yet. Click Add Route to create your first route.')}</div>`;
    }

    // Load routes
    function load() {
      routes = undefined;
      renderStats();
      OperatorApi.routeStatuses().then((s) => {
        statuses = s || {};
        if (Array.isArray(routes)) renderList();
      }).catch(() => {});
      AdminUi.loadInto(listEl, OperatorApi.myRoutes, (list) => {
        routes = list;
        renderStats();
        renderList();
      }).then(() => {
        if (!Array.isArray(routes)) statsEl.innerHTML = '';
      });
    }


    // Set active
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

    // Toggle routes
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

    // Remove routes
    function remove(route) {
      AdminModal.confirm({
        title: 'Delete route?',
        message: `${route.code} – ${route.name} will be removed permanently. This cannot be undone.`,
        confirmLabel: 'Delete',
        onConfirm: async () => {
          await OperatorApi.deleteRoute(route.id);
          routes = routes.filter((r) => r.id !== route.id);
          AdminUi.toast(`${route.code} – ${route.name} was deleted.`);
          renderStats();
          renderList();
        },
      });
    }

    listEl.addEventListener('change', (e) => {
      const select = e.target.closest('select[data-action="status"]');
      if (!select || !Array.isArray(routes)) return;
      const route = routes.find((r) => r.id === select.dataset.id);
      if (route) changeStatus(route, select.value);
    });

    listEl.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-action]');
      if (!btn || !Array.isArray(routes)) return;
      const route = routes.find((r) => r.id === btn.dataset.id);
      if (!route) return;
      if (btn.dataset.action === 'toggle') toggle(route);
      else if (btn.dataset.action === 'delete') remove(route);
      else if (btn.dataset.action === 'stops') {
        StopEditor.open(route, {
          onSaved: (saved) => {
            route.stop_count = saved.stops.length;
            renderList();
          },
        });
      }
    });

    // Toggle form
    const toggleForm = () => {
      showForm = !showForm;
      renderForm();
    };

    toggleBtn.addEventListener('click', () => {
      if (showForm) toggleForm();
      else OperatorUi.whenVerified(toggleForm);
    });

    renderForm();
    load();

    return () => formPicker?.destroy();
  },
});
